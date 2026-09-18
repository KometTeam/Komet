package session

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/vmihailenco/msgpack/v5"

	"push_server/internal/protocol"
)

// ErrAuthRejected возвращается когда сервер отклонил логин (невалидный токен).
var ErrAuthRejected = errors.New("auth rejected")

type PushHandler interface {
	OnMessage(chatID, senderID, msgID, msgTime int64, text, msgType, mediaURL string, unread int)
	OnMarkRead(chatID int64)
	OnCallHistory(callerID, chatID int64, hangupType string, durationMs int64)
	OnCallStart(callerID int64, conversationId, callType, vcp string)
}

type ChatInfo struct {
	Title     string
	IsChat    bool
	IsChannel bool
	IconUrl   string
}

type Config struct {
	Host       string
	Port       int
	LoginToken string
	DeviceID   string
}

type Client struct {
	config  Config
	handler PushHandler
	conn    net.Conn
	seq     uint16
	writeMu sync.Mutex
	pending sync.Map
	readErr chan error
	closed  chan struct{}
}

func NewClient(cfg Config, h PushHandler) *Client {
	return &Client{config: cfg, handler: h}
}

func (c *Client) Connect(ctx context.Context) error {
	if err := c.connectTransport(ctx); err != nil {
		return err
	}
	if err := c.handshake(); err != nil {
		c.conn.Close()
		<-c.readErr
		return err
	}
	return nil
}

func (c *Client) ConnectAnonymous(ctx context.Context) error {
	if err := c.connectTransport(ctx); err != nil {
		return err
	}
	if err := c.initSession(); err != nil {
		c.conn.Close()
		<-c.readErr
		return err
	}
	return nil
}

func (c *Client) connectTransport(ctx context.Context) error {
	addr := net.JoinHostPort(c.config.Host, fmt.Sprintf("%d", c.config.Port))
	d := &tls.Dialer{
		Config: &tls.Config{
			InsecureSkipVerify: true,
		},
	}
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		return fmt.Errorf("dial %s: %w", addr, err)
	}
	c.conn = conn
	c.closed = make(chan struct{})
	c.readErr = make(chan error, 1)
	go c.readLoop()
	return nil
}

func (c *Client) Close() {
	c.conn.Close()
}

func (c *Client) handshake() error {
	if err := c.initSession(); err != nil {
		return err
	}
	loginPayload, err := buildLogin(c.config.LoginToken)
	if err != nil {
		return fmt.Errorf("build login: %w", err)
	}
	resp, err := c.sendRequest(protocol.OpLogin, loginPayload)
	if err != nil {
		if resp != nil && resp.Cmd == protocol.CmdError {
			return fmt.Errorf("login: %w", ErrAuthRejected)
		}
		return fmt.Errorf("login: %w", err)
	}
	return nil
}

func (c *Client) initSession() error {
	initPayload, err := buildSessionInit(c.config.DeviceID)
	if err != nil {
		return fmt.Errorf("build session init: %w", err)
	}
	if _, err := c.sendRequest(protocol.OpSessionInit, initPayload); err != nil {
		return fmt.Errorf("session init: %w", err)
	}
	return nil
}

func (c *Client) Serve(ctx context.Context) error {
	select {
	case <-ctx.Done():
		c.conn.Close()
		<-c.readErr
		return ctx.Err()
	case err := <-c.readErr:
		return err
	}
}

func (c *Client) readLoop() {
	defer close(c.closed)
	for {
		frame, err := protocol.ReadFrame(c.conn)
		if err != nil {
			c.readErr <- err
			return
		}
		c.dispatch(frame)
	}
}

func (c *Client) dispatch(f *protocol.Frame) {
	if f.Cmd == protocol.CmdRequest {
		switch f.Opcode {
		case protocol.OpPing:
			c.respondOK(f.Seq, protocol.OpPing)
		case protocol.OpNotifMessage:
			go c.handleMessage(f.Payload)
		case protocol.OpNotifMark:
			go c.handleMark(f.Payload)
		case protocol.OpNotifCallHistory:
			go c.handleCallHistory(f.Payload)
		case protocol.OpNotifCallStart:
			go c.handleCallStart(f.Payload)
		}
		return
	}
	if ch, ok := c.pending.LoadAndDelete(f.Seq); ok {
		ch.(chan *protocol.Frame) <- f
	}
}

func (c *Client) respondOK(seq uint16, opcode uint16) {
	frame := &protocol.Frame{Cmd: protocol.CmdOK, Seq: seq, Opcode: opcode}
	data, err := frame.Marshal()
	if err != nil {
		return
	}
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_, _ = c.conn.Write(data)
}

func (c *Client) sendRequest(opcode uint16, payload []byte) (*protocol.Frame, error) {
	c.writeMu.Lock()
	c.seq++
	seq := c.seq
	c.writeMu.Unlock()

	ch := make(chan *protocol.Frame, 1)
	c.pending.Store(seq, ch)
	defer c.pending.Delete(seq)

	frame := &protocol.Frame{Cmd: protocol.CmdRequest, Seq: seq, Opcode: opcode, Payload: payload}
	data, err := frame.Marshal()
	if err != nil {
		return nil, err
	}
	c.writeMu.Lock()
	_, werr := c.conn.Write(data)
	c.writeMu.Unlock()
	if werr != nil {
		return nil, werr
	}

	select {
	case resp := <-ch:
		if resp.Cmd != protocol.CmdOK {
			return resp, fmt.Errorf("request opcode %d failed: cmd=%d", opcode, resp.Cmd)
		}
		return resp, nil
	case <-time.After(30 * time.Second):
		return nil, errors.New("request timeout")
	case <-c.closed:
		return nil, errors.New("connection closed")
	}
}

func (c *Client) SendRequest(opcode uint16, payload []byte) (*protocol.Frame, error) {
	return c.sendRequest(opcode, payload)
}

func buildSessionInit(deviceID string) ([]byte, error) {
	userAgent := map[string]interface{}{
		"deviceType":     "DESKTOP",
		"appVersion":     "26.23.2",
		"osVersion":      "Ubuntu 24.04 LTS",
		"timezone":       "Europe/Moscow",
		"screen":         "2560x1440 1.0x",
		"pushDeviceType": "GCM",
		"arch":           "arm64-v8a",
		"locale":         "ru",
		"buildNumber":    6779,
		"deviceName":     "SSRV PurpleTree Services",
		"deviceLocale":   "ru",
	}
	m := map[string]interface{}{
		"userAgent":       userAgent,
		"deviceId":        deviceID,
		"instanceId":      uuid.NewString(),
		"clientSessionId": rand.Int31(),
	}
	return msgpack.Marshal(m)
}

func buildLogin(loginToken string) ([]byte, error) {
	m := map[string]interface{}{
		"token":        loginToken,
		"interactive":  false,
		"chatsCount":   0,
		"chatsSync":    0,
		"contactsSync": 0,
		"presenceSync": -1,
		"draftsSync":   0,
	}
	return msgpack.Marshal(m)
}

func (c *Client) handleMessage(payload []byte) {
	var msg map[string]interface{}
	if err := msgpack.Unmarshal(payload, &msg); err != nil {
		return
	}
	chatID := toInt64(msg["chatId"])
	unread := int(toInt64(msg["unread"]))
	message, _ := msg["message"].(map[string]interface{})
	var senderID int64
	var msgID int64
	var msgTime int64
	var text string
	var msgType string
	var msgTypeLabel string
	var mediaURL string
	var hasCallAttach bool
	if message != nil {
		senderID = toInt64(message["sender"])
		msgID = toInt64(message["id"])
		msgTime = toInt64(message["time"])
		if t, ok := message["text"].(string); ok {
			text = t
		}
		if t, ok := message["type"].(string); ok {
			msgType = t
		}
		if attaches, ok := message["attaches"].([]interface{}); ok {
			for _, a := range attaches {
				am, _ := a.(map[string]interface{})
				if am == nil {
					continue
				}
				at, _ := am["_type"].(string)
				if at == "CALL" {
					hasCallAttach = true
					continue
				}
				if msgTypeLabel == "" {
					msgTypeLabel, mediaURL = parseAttachForPreview(am)
				}
			}
		}
	}
	log.Printf("incoming chatID=%d senderID=%d text=%q type=%q mediaType=%q mediaURL=%q hasCall=%v unread=%d", chatID, senderID, text, msgType, msgTypeLabel, mediaURL, hasCallAttach, unread)
	if message != nil {
		log.Printf("  message keys: %v", msgKeys(message))
		if attaches, ok := message["attaches"].([]interface{}); ok && len(attaches) > 0 {
			for i, a := range attaches {
				am, _ := a.(map[string]interface{})
				log.Printf("  attach[%d] keys: %v", i, msgKeys(am))
			}
		}
	}
	if hasCallAttach {
		log.Printf("  → skipped (CALL attach, callHistory handler will notify)")
		return
	}
	if c.handler != nil {
		c.handler.OnMessage(chatID, senderID, msgID, msgTime, text, msgTypeLabel, mediaURL, unread)
	}
}

func parseAttachForPreview(am map[string]interface{}) (msgType, mediaURL string) {
	t, _ := am["_type"].(string)
	switch t {
	case "PHOTO":
		msgType = "photo"
		if u, ok := am["baseUrl"].(string); ok && u != "" {
			mediaURL = u
		} else if u, ok := am["url"].(string); ok && u != "" {
			mediaURL = u
		}
	case "VIDEO":
		if toInt64(am["videoType"]) == 1 {
			msgType = "videonote"
		} else {
			msgType = "video"
		}
		if u, ok := am["thumbnail"].(string); ok && u != "" {
			mediaURL = u
		} else if u, ok := am["baseUrl"].(string); ok && u != "" {
			mediaURL = u
		}
	case "AUDIO":
		if hasWaveform(am) {
			msgType = "voice"
		} else {
			msgType = "audio"
		}
	case "FILE":
		msgType = "file"
		if pr, ok := am["preview"].(map[string]interface{}); ok {
			if u, ok := pr["baseUrl"].(string); ok && u != "" {
				mediaURL = u
			}
		}
	case "LOCATION":
		msgType = "geo"
	case "CONTACT":
		msgType = "contact"
	}
	return
}

func hasWaveform(am map[string]interface{}) bool {
	if _, ok := am["wave"]; ok {
		return true
	}
	return false
}

func msgKeys(m map[string]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

func mapKeys(m map[interface{}]interface{}) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, fmt.Sprintf("%v", k))
	}
	return keys
}

func (c *Client) handleMark(payload []byte) {
	var m map[string]interface{}
	if err := msgpack.Unmarshal(payload, &m); err != nil {
		return
	}
	setAsUnread, _ := m["setAsUnread"].(bool)
	if setAsUnread {
		return
	}
	chatID := toInt64(m["chatId"])
	if c.handler != nil {
		c.handler.OnMarkRead(chatID)
	}
}

func (c *Client) handleCallHistory(payload []byte) {
	var m map[string]interface{}
	if err := msgpack.Unmarshal(payload, &m); err != nil {
		return
	}
	items, _ := m["callHistoryItems"].([]interface{})
	for _, it := range items {
		item, _ := it.(map[string]interface{})
		if item == nil {
			continue
		}
		hangupType, _ := item["hangupType"].(string)
		durationMs := toInt64(item["durationMs"])
		if durationMs != 0 {
			continue
		}
		if hangupType != "MISSED" && hangupType != "CANCELED" {
			continue
		}
		callerID := toInt64(item["callerId"])
		chatID := toInt64(item["chatId"])
		if c.handler != nil {
			c.handler.OnCallHistory(callerID, chatID, hangupType, durationMs)
		}
	}
}

func (c *Client) handleCallStart(payload []byte) {
	var m map[string]interface{}
	if err := msgpack.Unmarshal(payload, &m); err != nil {
		return
	}
	callerID := toInt64(m["callerId"])
	conversationId, _ := m["conversationId"].(string)
	callType, _ := m["type"].(string)
	vcp, _ := m["vcp"].(string)
	if c.handler != nil {
		c.handler.OnCallStart(callerID, conversationId, callType, vcp)
	}
}

func toInt64(v interface{}) int64 {
	switch n := v.(type) {
	case int:
		return int64(n)
	case int8:
		return int64(n)
	case int16:
		return int64(n)
	case int32:
		return int64(n)
	case int64:
		return int64(n)
	case uint:
		return int64(n)
	case uint8:
		return int64(n)
	case uint16:
		return int64(n)
	case uint32:
		return int64(n)
	case uint64:
		return int64(n)
	case float64:
		return int64(n)
	}
	return 0
}
