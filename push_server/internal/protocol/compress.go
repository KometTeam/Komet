package protocol

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"

	"github.com/klauspost/compress/zstd"
	"github.com/pierrec/lz4/v4"
)

var (
	zstdMagic     = []byte{0x28, 0xB5, 0x2F, 0xFD}
	lz4FrameMagic = []byte{0x04, 0x22, 0x4D, 0x18}
)

func Decompress(src []byte) ([]byte, error) {
	if len(src) >= 4 && bytes.Equal(src[:4], zstdMagic) {
		return zstdDecompress(src)
	}
	if len(src) >= 4 && bytes.Equal(src[:4], lz4FrameMagic) {
		return lz4FrameDecompress(src)
	}
	return lz4BlockDecompress(src)
}

func zstdDecompress(src []byte) ([]byte, error) {
	dec, err := zstd.NewReader(bytes.NewReader(src))
	if err != nil {
		return nil, err
	}
	defer dec.Close()
	return io.ReadAll(dec)
}

func lz4FrameDecompress(src []byte) ([]byte, error) {
	r := lz4.NewReader(bytes.NewReader(src))
	return io.ReadAll(r)
}

func lz4BlockDecompress(src []byte) ([]byte, error) {
	dst := make([]byte, 0, len(src)*4)
	pos := 0
	for pos < len(src) {
		token := src[pos]
		pos++
		litLen := int(token >> 4)
		if litLen == 15 {
			for pos < len(src) {
				b := src[pos]
				pos++
				litLen += int(b)
				if b != 255 {
					break
				}
			}
		}
		if pos+litLen > len(src) {
			return nil, errors.New("lz4 block: literal length out of range")
		}
		dst = append(dst, src[pos:pos+litLen]...)
		pos += litLen
		if pos >= len(src) {
			break
		}
		if pos+2 > len(src) {
			return nil, errors.New("lz4 block: truncated offset")
		}
		offset := int(src[pos]) | int(src[pos+1])<<8
		pos += 2
		matchLen := int(token&0x0F) + 4
		if token&0x0F == 0x0F {
			for pos < len(src) {
				b := src[pos]
				pos++
				matchLen += int(b)
				if b != 255 {
					break
				}
			}
		}
		if offset == 0 || offset > len(dst) {
			return nil, errors.New("lz4 block: invalid offset")
		}
		start := len(dst) - offset
		for i := 0; i < matchLen; i++ {
			dst = append(dst, dst[start+i])
		}
	}
	return dst, nil
}

func Compress(src []byte) ([]byte, byte, error) {
	if len(src) < 32 {
		return src, 0, nil
	}
	compressed := lz4BlockCompress(src)
	if compressed == nil || len(compressed) >= len(src) {
		return src, 0, nil
	}
	flag := byte(len(src)/len(compressed)) + 1
	if flag == 0 {
		flag = 1
	}
	return compressed, flag, nil
}

const (
	lz4MfLimit  = 12
	lz4MinMatch = 4
	lz4HashLog  = 14
	lz4HashSize = 1 << lz4HashLog
	lz4LastLits = 5
)

func lz4BlockCompress(src []byte) []byte {
	if len(src) < lz4MfLimit {
		dst := make([]byte, 0, len(src)+1)
		writeLiterals(&dst, src)
		return dst
	}
	dst := make([]byte, 0, len(src)+len(src)/255+16)
	hashTable := make([]int, lz4HashSize)
	for i := range hashTable {
		hashTable[i] = -1
	}
	limit := len(src) - lz4MfLimit
	anchor := 0
	pos := 0
	for pos < limit {
		h := lz4Hash(src, pos)
		candidate := hashTable[h]
		hashTable[h] = pos
		if candidate < 0 || pos-candidate >= 65536 {
			pos++
			continue
		}
		if binary.LittleEndian.Uint32(src[candidate:]) != binary.LittleEndian.Uint32(src[pos:]) {
			pos++
			continue
		}
		back := 0
		for pos-back > anchor && candidate-back > 0 && src[pos-back-1] == src[candidate-back-1] {
			back++
		}
		matchPos := candidate - back
		startPos := pos - back
		maxMatchEnd := len(src) - lz4LastLits
		if maxMatchEnd < startPos+lz4MinMatch {
			pos++
			continue
		}
		matchLen := 0
		for startPos+matchLen < maxMatchEnd && src[matchPos+matchLen] == src[startPos+matchLen] {
			matchLen++
		}
		if matchLen < lz4MinMatch {
			pos++
			continue
		}
		emitMatch(&dst, src[anchor:startPos], startPos-matchPos, matchLen-lz4MinMatch)
		pos = startPos + matchLen
		anchor = pos
	}
	writeLiterals(&dst, src[anchor:])
	return dst
}

func lz4Hash(src []byte, pos int) uint32 {
	v := binary.LittleEndian.Uint32(src[pos:])
	return (v * 2654435761) >> (32 - lz4HashLog)
}

func emitMatch(dst *[]byte, lits []byte, offset, matchCode int) {
	litLen := len(lits)
	var token byte
	if litLen >= 15 {
		token = 15 << 4
	} else {
		token = byte(litLen) << 4
	}
	if matchCode >= 15 {
		token |= 15
	} else {
		token |= byte(matchCode)
	}
	*dst = append(*dst, token)
	if litLen >= 15 {
		n := litLen - 15
		for n >= 255 {
			*dst = append(*dst, 255)
			n -= 255
		}
		*dst = append(*dst, byte(n))
	}
	*dst = append(*dst, lits...)
	*dst = append(*dst, byte(offset), byte(offset>>8))
	if matchCode >= 15 {
		n := matchCode - 15
		for n >= 255 {
			*dst = append(*dst, 255)
			n -= 255
		}
		*dst = append(*dst, byte(n))
	}
}

func writeLiterals(dst *[]byte, lits []byte) {
	litLen := len(lits)
	var token byte
	if litLen >= 15 {
		token = 15 << 4
	} else {
		token = byte(litLen) << 4
	}
	*dst = append(*dst, token)
	if litLen >= 15 {
		n := litLen - 15
		for n >= 255 {
			*dst = append(*dst, 255)
			n -= 255
		}
		*dst = append(*dst, byte(n))
	}
	*dst = append(*dst, lits...)
}
