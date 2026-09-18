package session

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/vmihailenco/msgpack/v5"
)

func TestQrCreateOnNativeTCP(t *testing.T) {
	if os.Getenv("PUSH_QR_PROBE") == "" {
		t.Skip("set PUSH_QR_PROBE=1 to probe QrCreate on native TCP")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	cli := NewClient(Config{
		Host:     "api2.oneme.ru",
		Port:     443,
		DeviceID: "11111111-2222-3333-4444-555555555555",
	}, nopHandler{})

	if err := cli.ConnectAnonymous(ctx); err != nil {
		t.Fatalf("anonymous connect: %v", err)
	}
	defer cli.Close()

	resp, err := cli.SendRequest(288, nil)
	if err != nil {
		t.Fatalf("QrCreate: %v", err)
	}
	t.Logf("QrCreate cmd=%d payload=%s", resp.Cmd, string(resp.Payload))

	payload, err := msgpack.Marshal(map[string]interface{}{"trackId": "probe"})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	resp2, err := cli.SendRequest(289, payload)
	if err != nil {
		t.Logf("QrStatus: %v", err)
	} else {
		t.Logf("QrStatus cmd=%d payload=%s", resp2.Cmd, string(resp2.Payload))
	}
}

type nopHandler struct{}

func (nopHandler) OnMessage(int64, int64, int64, int64, string, string, string, int) {}
func (nopHandler) OnMarkRead(int64)                                                  {}
func (nopHandler) OnCallHistory(int64, int64, string, int64)                         {}
func (nopHandler) OnCallStart(int64, string, string, string)                         {}
