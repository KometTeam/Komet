package protocol

import (
	"encoding/binary"
	"fmt"
	"io"
)

type Frame struct {
	Cmd     byte
	Seq     uint16
	Opcode  uint16
	Payload []byte
}

const headerLen = 10

func (f *Frame) Marshal() ([]byte, error) {
	payload := f.Payload
	compFlag := byte(0)
	if len(payload) >= 32 {
		compressed, flag, err := Compress(payload)
		if err == nil && flag != 0 {
			payload = compressed
			compFlag = flag
		}
	}
	buf := make([]byte, headerLen+len(payload))
	buf[0] = Version
	buf[1] = f.Cmd
	binary.BigEndian.PutUint16(buf[2:4], f.Seq)
	binary.BigEndian.PutUint16(buf[4:6], f.Opcode)
	packed := uint32(compFlag)<<24 | uint32(len(payload)&0xFFFFFF)
	binary.BigEndian.PutUint32(buf[6:10], packed)
	copy(buf[headerLen:], payload)
	return buf, nil
}

func ReadFrame(r io.Reader) (*Frame, error) {
	header := make([]byte, headerLen)
	if _, err := io.ReadFull(r, header); err != nil {
		return nil, err
	}
	if header[0] != Version {
		return nil, fmt.Errorf("unexpected frame version %d", header[0])
	}
	packed := binary.BigEndian.Uint32(header[6:10])
	compFlag := byte(packed >> 24)
	payloadLen := int(packed & 0xFFFFFF)
	payload := make([]byte, payloadLen)
	if _, err := io.ReadFull(r, payload); err != nil {
		return nil, err
	}
	if compFlag != 0 {
		decompressed, err := Decompress(payload)
		if err != nil {
			return nil, fmt.Errorf("decompress: %w", err)
		}
		payload = decompressed
	}
	return &Frame{
		Cmd:     header[1],
		Seq:     binary.BigEndian.Uint16(header[2:4]),
		Opcode:  binary.BigEndian.Uint16(header[4:6]),
		Payload: payload,
	}, nil
}
