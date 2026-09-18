package session

import (
	"bytes"
	"testing"

	"github.com/vmihailenco/msgpack/v5"
)

func TestBuildLoginExpChatsCountGroups(t *testing.T) {
	payload, err := buildLogin("token-abc")
	if err != nil {
		t.Fatalf("buildLogin: %v", err)
	}
	var m map[string]interface{}
	if err := msgpack.Unmarshal(payload, &m); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	exp, ok := m["exp"].(map[string]interface{})
	if !ok {
		t.Fatalf("exp is not a map: %T", m["exp"])
	}
	groups, ok := exp["chatsCountGroups"].([]byte)
	if !ok {
		t.Fatalf("chatsCountGroups not []byte: %T", exp["chatsCountGroups"])
	}
	if !bytes.Equal(groups, []byte{0x0b, 0x32}) {
		t.Fatalf("unexpected chatsCountGroups: %v", groups)
	}
	if toInt64(m["chatsSync"]) != -1 {
		t.Fatalf("chatsSync mismatch: %v", m["chatsSync"])
	}
}

func TestBuildSessionInitStructure(t *testing.T) {
	payload, err := buildSessionInit("device-uuid")
	if err != nil {
		t.Fatalf("buildSessionInit: %v", err)
	}
	var m map[string]interface{}
	if err := msgpack.Unmarshal(payload, &m); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	ua, ok := m["userAgent"].(map[string]interface{})
	if !ok {
		t.Fatalf("userAgent not a map: %T", m["userAgent"])
	}
	if ua["deviceType"] != "DESKTOP" {
		t.Fatalf("unexpected deviceType: %v", ua["deviceType"])
	}
	if ua["pushDeviceType"] != "GCM" {
		t.Fatalf("unexpected pushDeviceType: %v", ua["pushDeviceType"])
	}
	if m["deviceId"] != "device-uuid" {
		t.Fatalf("unexpected deviceId: %v", m["deviceId"])
	}
}
