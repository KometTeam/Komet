package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"push_server/internal/link"
	"push_server/internal/session"
	"push_server/internal/store"
)

type Handler struct {
	manager *session.Manager
	store   *store.Store
	links   *link.Manager
}

func NewHandler(m *session.Manager, s *store.Store, l *link.Manager) *Handler {
	return &Handler{manager: m, store: s, links: l}
}

func (h *Handler) Routes(mux *http.ServeMux) {
	mux.HandleFunc("/register", h.register)
	mux.HandleFunc("/unregister", h.unregister)
	mux.HandleFunc("/verify", h.verify)
	mux.HandleFunc("/avatar-colors", h.avatarColors)
	mux.HandleFunc("/badge", h.badge)
	mux.HandleFunc("/state", h.state)
	mux.HandleFunc("/reply", h.reply)
	mux.HandleFunc("/health", h.health)
	mux.HandleFunc("/link/start", h.linkStart)
	mux.HandleFunc("/link/status", h.linkStatus)
	mux.HandleFunc("/link/password", h.linkPassword)
	mux.HandleFunc("/link/cancel", h.linkCancel)
}

type registerRequest struct {
	APNSToken     string `json:"apns_token"`
	VoIPToken     string `json:"voip_token"`
	LoginToken    string `json:"login_token"`
	AccountID     int64  `json:"account_id"`
	DeviceID      string `json:"device_id"`
	IsDevelopment bool   `json:"is_development"`
}

type unregisterRequest struct {
	APNSToken string `json:"apns_token"`
}

type stateRequest struct {
	APNSToken  string `json:"apns_token"`
	Foreground bool   `json:"foreground"`
}

type verifyRequest struct {
	APNSToken     string `json:"apns_token"`
	VoIPToken     string `json:"voip_token"`
	AccountID     *int64 `json:"account_id"`
	DeviceID      string `json:"device_id"`
	IsDevelopment *bool  `json:"is_development"`
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.APNSToken == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing required fields"})
		return
	}
	if err := h.manager.Register(session.RegisterRequest{
		APNSToken:  req.APNSToken,
		VoIPToken:  req.VoIPToken,
		LoginToken: req.LoginToken,
		AccountID:  req.AccountID,
		DeviceID:   req.DeviceID,
		IsDev:      req.IsDevelopment,
	}); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "registered"})
}

func (h *Handler) linkStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	view, err := h.links.Start(req.APNSToken, req.VoIPToken, req.DeviceID, req.IsDevelopment)
	if err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, view)
}

func (h *Handler) linkStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req linkIDRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	view, err := h.links.Status(req.LinkID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, view)
}

func (h *Handler) linkPassword(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req linkPasswordRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	view, err := h.links.Password(req.LinkID, req.Password)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, view)
}

func (h *Handler) linkCancel(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req linkIDRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if err := h.links.Cancel(req.LinkID); err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "cancelled"})
}

type linkIDRequest struct {
	LinkID string `json:"link_id"`
}

type linkPasswordRequest struct {
	LinkID   string `json:"link_id"`
	Password string `json:"password"`
}

func (h *Handler) unregister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req unregisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if err := h.manager.Unregister(req.APNSToken); err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "unregistered"})
}

func (h *Handler) verify(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req verifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.APNSToken == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing apns_token"})
		return
	}
	vreq := session.VerifyRequest{
		APNSToken: req.APNSToken,
		VoIPToken: req.VoIPToken,
		DeviceID:  req.DeviceID,
		HasVoIP:   req.VoIPToken != "",
		HasDevice: req.DeviceID != "",
	}
	if req.AccountID != nil {
		vreq.HasAccount = true
		vreq.AccountID = *req.AccountID
	}
	if req.IsDevelopment != nil {
		vreq.HasIsDev = true
		vreq.IsDevelopment = *req.IsDevelopment
	}
	resp := h.manager.Verify(vreq)
	writeJSON(w, http.StatusOK, map[string]interface{}{
		"registered":             resp.Registered,
		"voip_token_present":     resp.VoIPTokenPresent,
		"voip_token_matches":     resp.VoIPTokenMatches,
		"account_id_matches":     resp.AccountIDMatches,
		"device_id_matches":      resp.DeviceIDMatches,
		"is_development_matches": resp.IsDevelopmentMatches,
		"login_token_present":    resp.LoginTokenPresent,
	})
}

type avatarColorsRequest struct {
	APNSToken string `json:"apns_token"`
	LightBg   string `json:"light_bg"`
	LightFg   string `json:"light_fg"`
	DarkBg    string `json:"dark_bg"`
	DarkFg    string `json:"dark_fg"`
}

func (h *Handler) avatarColors(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req avatarColorsRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.APNSToken == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing apns_token"})
		return
	}
	if err := h.manager.SetAvatarColors(req.APNSToken, req.LightBg, req.LightFg, req.DarkBg, req.DarkFg); err == nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
		return
	}
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "session not found"})
}

type badgeRequest struct {
	APNSToken string         `json:"apns_token"`
	Chats     map[string]int `json:"chats"`
}

func (h *Handler) badge(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req badgeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.APNSToken == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing apns_token"})
		return
	}
	m := make(map[int64]int, len(req.Chats))
	for k, v := range req.Chats {
		if id, err := strconv.ParseInt(k, 10, 64); err == nil && v > 0 {
			m[id] = v
		}
	}
	if _, ok := h.store.Get(req.APNSToken); ok {
		h.manager.SetUnreadMap(req.APNSToken, m)
		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
		return
	}
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "session not found"})
}

func (h *Handler) state(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req stateRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if err := h.manager.SetForeground(req.APNSToken, req.Foreground); err == nil {
		writeJSON(w, http.StatusOK, map[string]string{"status": "updated"})
		return
	}
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "session not found"})
}

type replyRequest struct {
	APNSToken string `json:"apns_token"`
	ChatID    int64  `json:"chat_id"`
	ReplyTo   int64  `json:"reply_to"`
	Mark      int64  `json:"mark"`
	Text      string `json:"text"`
}

func (h *Handler) reply(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w)
		return
	}
	var req replyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid json"})
		return
	}
	if req.APNSToken == "" || req.ChatID == 0 || req.Text == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing required fields"})
		return
	}
	if err := h.manager.Reply(req.APNSToken, req.ChatID, req.ReplyTo, req.Mark, req.Text); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "sent"})
}

func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func methodNotAllowed(w http.ResponseWriter) {
	writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
}
