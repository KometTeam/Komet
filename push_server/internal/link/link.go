package link

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/vmihailenco/msgpack/v5"

	"push_server/internal/protocol"
	"push_server/internal/session"
)

type Status string

const (
	StatusWaiting  Status = "waiting"
	StatusPassword Status = "password"
	StatusDone     Status = "done"
	StatusExpired  Status = "expired"
)

type View struct {
	ID        string    `json:"link_id"`
	QrLink    string    `json:"qr_link,omitempty"`
	ExpiresAt time.Time `json:"expires_at"`
	PollEvery int       `json:"poll_every_ms"`
	Status    Status    `json:"status"`
	AccountID int64     `json:"account_id,omitempty"`
	Hint      string    `json:"hint,omitempty"`
}

type link struct {
	id        string
	trackID   string
	apnsToken string
	voipToken string
	deviceID  string
	isDev     bool
	client    *session.Client
	expiresAt time.Time
	pollEvery time.Duration

	mu        sync.Mutex
	status    Status
	hint      string
	challenge string
	accountID int64
	lastPoll  time.Time
}

type Manager struct {
	mu       sync.Mutex
	links    map[string]*link
	pending  map[string]string
	sessions *session.Manager
	maxHost  string
	maxPort  int
}

func NewManager(sessions *session.Manager, maxHost string, maxPort int) *Manager {
	return &Manager{
		links:    make(map[string]*link),
		pending:  make(map[string]string),
		sessions: sessions,
		maxHost:  maxHost,
		maxPort:  maxPort,
	}
}

func (m *Manager) Start(apnsToken, voipToken, deviceID string, isDev bool) (View, error) {
	if apnsToken == "" {
		return View{}, errors.New("missing apns_token")
	}

	m.mu.Lock()
	if oldID, ok := m.pending[apnsToken]; ok {
		if old, ok := m.links[oldID]; ok && old != nil {
			old.mu.Lock()
			if old.client != nil {
				old.client.Close()
				old.client = nil
			}
			old.status = StatusExpired
			old.mu.Unlock()
		}
		delete(m.links, oldID)
	}
	m.mu.Unlock()

	client := session.NewClient(session.Config{
		Host:     m.maxHost,
		Port:     m.maxPort,
		DeviceID: uuid.NewString(),
	}, nopHandler{})

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := client.ConnectAnonymous(ctx); err != nil {
		return View{}, fmt.Errorf("auth connect: %w", err)
	}

	resp, err := client.SendRequest(protocol.OpQrCreate, nil)
	if err != nil {
		client.Close()
		return View{}, fmt.Errorf("qr create: %w", err)
	}

	var payload map[string]interface{}
	if err := msgpack.Unmarshal(resp.Payload, &payload); err != nil {
		client.Close()
		return View{}, fmt.Errorf("qr decode: %w", err)
	}

	trackID, _ := payload["trackId"].(string)
	qrLink, _ := payload["qrLink"].(string)
	if trackID == "" || qrLink == "" {
		client.Close()
		return View{}, errors.New("qr create: пустой trackId/qrLink")
	}

	pollEvery := durationFrom(payload["pollingInterval"], 5*time.Second)
	ttl := durationFrom(payload["ttl"], 2*time.Minute)
	expiresAt := nowPlus(payload["expiresAt"], ttl)

	l := &link{
		id:        uuid.NewString(),
		trackID:   trackID,
		apnsToken: apnsToken,
		voipToken: voipToken,
		deviceID:  deviceID,
		isDev:     isDev,
		client:    client,
		expiresAt: expiresAt,
		pollEvery: pollEvery,
		status:    StatusWaiting,
	}

	m.mu.Lock()
	m.links[l.id] = l
	m.pending[apnsToken] = l.id
	m.mu.Unlock()

	log.Printf("link %s: создан для apns=%s (track %s)", l.id, shortToken(apnsToken), shortToken(trackID))
	return l.view(), nil
}

func (m *Manager) Status(id string) (View, error) {
	m.mu.Lock()
	l := m.links[id]
	m.mu.Unlock()
	if l == nil {
		return View{}, errors.New("link not found")
	}
	return l.poll(m), nil
}

func (m *Manager) Password(id, password string) (View, error) {
	m.mu.Lock()
	l := m.links[id]
	m.mu.Unlock()
	if l == nil {
		return View{}, errors.New("link not found")
	}

	l.mu.Lock()
	defer l.mu.Unlock()
	if l.status != StatusPassword || l.client == nil {
		return l.view(), nil
	}

	payload, err := msgpack.Marshal(map[string]interface{}{
		"trackId":  l.challenge,
		"password": password,
	})
	if err != nil {
		return View{}, err
	}
	resp, err := l.client.SendRequest(protocol.OpAuthCheckPass, payload)
	if err != nil {
		return l.view(), errors.New("неверный пароль")
	}

	var decoded map[string]interface{}
	if err := msgpack.Unmarshal(resp.Payload, &decoded); err != nil {
		return View{}, fmt.Errorf("password decode: %w", err)
	}
	return m.completeLocked(l, decoded), nil
}

func (m *Manager) Cancel(id string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	l, ok := m.links[id]
	if !ok {
		return errors.New("link not found")
	}
	l.mu.Lock()
	if l.client != nil {
		l.client.Close()
		l.client = nil
	}
	l.status = StatusExpired
	l.mu.Unlock()
	delete(m.links, id)
	delete(m.pending, l.apnsToken)
	return nil
}

func (m *Manager) Cleanup() {
	m.mu.Lock()
	ids := make([]string, 0, len(m.links))
	for id := range m.links {
		ids = append(ids, id)
	}
	m.mu.Unlock()

	for _, id := range ids {
		m.mu.Lock()
		l := m.links[id]
		m.mu.Unlock()
		if l == nil {
			continue
		}
		l.mu.Lock()
		expired := time.Now().After(l.expiresAt)
		l.mu.Unlock()
		if expired {
			_ = m.Cancel(id)
		}
	}
}

func (l *link) poll(m *Manager) View {
	l.mu.Lock()
	defer l.mu.Unlock()

	if l.status == StatusDone || l.status == StatusExpired {
		return l.view()
	}
	if time.Now().After(l.expiresAt) || l.client == nil {
		l.status = StatusExpired
		if l.client != nil {
			l.client.Close()
			l.client = nil
		}
		return l.view()
	}
	if !l.lastPoll.IsZero() && time.Since(l.lastPoll) < l.pollEvery {
		return l.view()
	}
	l.lastPoll = time.Now()

	payload, err := msgpack.Marshal(map[string]interface{}{"trackId": l.trackID})
	if err != nil {
		return l.view()
	}
	resp, err := l.client.SendRequest(protocol.OpQrStatus, payload)
	if err != nil {
		log.Printf("link %s: status poll failed: %v", l.id, err)
		l.status = StatusExpired
		l.client.Close()
		l.client = nil
		return l.view()
	}

	var decoded map[string]interface{}
	if err := msgpack.Unmarshal(resp.Payload, &decoded); err != nil {
		return l.view()
	}
	state, _ := decoded["status"].(map[string]interface{})
	available := false
	if state != nil {
		available, _ = state["loginAvailable"].(bool)
	}
	if !available {
		l.status = StatusWaiting
		return l.view()
	}

	finishPayload, err := msgpack.Marshal(map[string]interface{}{"trackId": l.trackID})
	if err != nil {
		return l.view()
	}
	finish, err := l.client.SendRequest(protocol.OpQrFinish, finishPayload)
	if err != nil {
		return l.view()
	}
	var done map[string]interface{}
	if err := msgpack.Unmarshal(finish.Payload, &done); err != nil {
		return l.view()
	}
	return m.completeLocked(l, done)
}

func (m *Manager) completeLocked(l *link, payload map[string]interface{}) View {
	if token := tokenFromAttrs(payload); token != "" {
		if err := m.sessions.Register(session.RegisterRequest{
			APNSToken:  l.apnsToken,
			VoIPToken:  l.voipToken,
			LoginToken: token,
			AccountID:  accountIDFromPayload(payload),
			DeviceID:   l.deviceID,
			IsDev:      l.isDev,
		}); err != nil {
			log.Printf("link %s: bind failed: %v", l.id, err)
			l.status = StatusExpired
			return l.view()
		}
		l.status = StatusDone
		l.accountID = accountIDFromPayload(payload)
		l.challenge = ""
		l.hint = ""
		if l.client != nil {
			l.client.Close()
			l.client = nil
		}
		m.mu.Lock()
		delete(m.pending, l.apnsToken)
		m.mu.Unlock()
		log.Printf("link %s: привязан к apns=%s", l.id, shortToken(l.apnsToken))
		return l.view()
	}

	if challenge, ok := payload["passwordChallenge"].(map[string]interface{}); ok {
		if trackID, ok := challenge["trackId"].(string); ok && trackID != "" {
			l.status = StatusPassword
			l.challenge = trackID
			if hint, ok := challenge["hint"].(string); ok && hint != "" {
				l.hint = hint
			}
			return l.view()
		}
	}

	l.status = StatusExpired
	return l.view()
}

func (l *link) view() View {
	v := View{
		ID:        l.id,
		ExpiresAt: l.expiresAt,
		PollEvery: int(l.pollEvery / time.Millisecond),
		Status:    l.status,
		AccountID: l.accountID,
		Hint:      l.hint,
	}
	if l.status != StatusDone {
		v.QrLink = fmt.Sprintf("https://max.ru/:auth/%s", l.trackID)
	}
	return v
}

func tokenFromAttrs(payload map[string]interface{}) string {
	attrs, ok := payload["tokenAttrs"].(map[string]interface{})
	if !ok {
		return ""
	}
	login, ok := attrs["LOGIN"].(map[string]interface{})
	if !ok {
		return ""
	}
	token, _ := login["token"].(string)
	return token
}

func accountIDFromPayload(payload map[string]interface{}) int64 {
	profile, ok := payload["profile"].(map[string]interface{})
	if !ok {
		return 0
	}
	contact, ok := profile["contact"].(map[string]interface{})
	if !ok {
		return 0
	}
	if id, ok := contact["id"].(int64); ok {
		return id
	}
	if id, ok := contact["id"].(uint64); ok {
		return int64(id)
	}
	return 0
}

func durationFrom(value interface{}, fallback time.Duration) time.Duration {
	if v := toInt64(value); v > 0 {
		return time.Duration(v) * time.Millisecond
	}
	return fallback
}

func nowPlus(value interface{}, fallback time.Duration) time.Time {
	if v := toInt64(value); v > 0 {
		return time.UnixMilli(v)
	}
	return time.Now().Add(fallback)
}

func toInt64(value interface{}) int64 {
	switch v := value.(type) {
	case int64:
		return v
	case uint64:
		return int64(v)
	case int:
		return int64(v)
	case float64:
		return int64(v)
	default:
		return 0
	}
}

func shortToken(s string) string {
	if len(s) <= 12 {
		return s
	}
	return s[:12] + "…"
}

type nopHandler struct{}

func (nopHandler) OnMessage(int64, int64, int64, int64, string, string, string, int) {}
func (nopHandler) OnMarkRead(int64)                                                  {}
func (nopHandler) OnCallHistory(int64, int64, string, int64)                         {}
func (nopHandler) OnCallStart(int64, string, string, string)                         {}
