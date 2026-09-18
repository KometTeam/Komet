package protocol

import (
	"bytes"
	"math/rand"
	"testing"
)

func TestLZ4BlockRoundTrip(t *testing.T) {
	cases := [][]byte{
		bytes.Repeat([]byte{0x41}, 40),
		[]byte("hello world hello world hello world hello world hello world!!!!!"),
		append(bytes.Repeat([]byte("abc"), 30), bytes.Repeat([]byte{0x00}, 10)...),
	}
	rng := rand.New(rand.NewSource(42))
	randomBlob := make([]byte, 5000)
	for i := range randomBlob {
		randomBlob[i] = byte(rng.Intn(4))
	}
	cases = append(cases, randomBlob)

	for i, src := range cases {
		compressed, flag, err := Compress(src)
		if err != nil {
			t.Fatalf("case %d compress: %v", i, err)
		}
		if flag == 0 {
			continue
		}
		out, err := lz4BlockDecompress(compressed)
		if err != nil {
			t.Fatalf("case %d decompress: %v", i, err)
		}
		if !bytes.Equal(src, out) {
			t.Fatalf("case %d round-trip mismatch: got %d bytes, want %d", i, len(out), len(src))
		}
	}
}

func TestFrameRoundTrip(t *testing.T) {
	cases := [][]byte{
		[]byte("short payload under 32 bytes, no compression"),
		bytes.Repeat([]byte("compress me please "), 60),
		append(bytes.Repeat([]byte("abc"), 100), bytes.Repeat([]byte{0x00}, 50)...),
	}
	for i, src := range cases {
		f := &Frame{Cmd: CmdRequest, Seq: uint16(i + 1), Opcode: OpLogin, Payload: src}
		data, err := f.Marshal()
		if err != nil {
			t.Fatalf("case %d marshal: %v", i, err)
		}
		out, err := ReadFrame(bytes.NewReader(data))
		if err != nil {
			t.Fatalf("case %d read: %v", i, err)
		}
		if out.Cmd != f.Cmd || out.Seq != f.Seq || out.Opcode != f.Opcode || !bytes.Equal(out.Payload, src) {
			t.Fatalf("case %d frame mismatch", i)
		}
	}
}
