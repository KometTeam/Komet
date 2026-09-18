package session

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/vmihailenco/msgpack/v5"

	"push_server/internal/apns"
	"push_server/internal/protocol"
	"push_server/internal/store"
)

const (
	initialBackoff  = time.Second
	maxBackoff      = 60 * time.Second
	maxAuthFailures = 3
)

type RegisterRequest struct {
	APNSToken  string
	VoIPToken  string
	LoginToken string
	AccountID  int64
	DeviceID   string
	IsDev      bool
}

type VerifyRequest struct {
	APNSToken     string
	VoIPToken     string
	AccountID     int64
	DeviceID      string
	IsDevelopment bool
	HasVoIP       bool
	HasAccount    bool
	HasDevice     bool
	HasIsDev      bool
}

type VerifyResponse struct {
	Registered           bool
	VoIPTokenPresent     bool
	VoIPTokenMatches     bool
	AccountIDMatches     bool
	DeviceIDMatches      bool
	IsDevelopmentMatches bool
	LoginTokenPresent    bool
}

type Manager struct {
	store    *store.Store
	apns     *apns.Client
	maxHost  string
	maxPort  int
	sessions sync.Map
}

func NewManager(st *store.Store, ac *apns.Client, maxHost string, maxPort int) *Manager {
	return &Manager{store: st, apns: ac, maxHost: maxHost, maxPort: maxPort}
}

func (m *Manager) registerSession(token string, h *pushHandler) {
	m.sessions.Store(token, h)
}

func (m *Manager) unregisterSession(token string) {
	m.sessions.Delete(token)
}

func (m *Manager) SetUnreadMap(apnsToken string, m2 map[int64]int) bool {
	m.store.SetUnreadChats(apnsToken, m2)
	v, ok := m.sessions.Load(apnsToken)
	if !ok {
		return true
	}
	v.(*pushHandler).setUnreadMap(m2)
	return true
}

func (m *Manager) Restore() {
	for _, rec := range m.store.All() {
		ctx, cancel := context.WithCancel(context.Background())
		rec.Cancel = cancel
		go m.runSession(ctx, rec)
		log.Printf("restored session for %s (dev=%v)", rec.APNSToken, rec.IsDev)
	}
}

func (m *Manager) Register(req RegisterRequest) error {
	if req.APNSToken == "" {
		return errors.New("missing apns_token")
	}
	if req.LoginToken == "" {
		return m.UpdateTokens(req)
	}
	if existing, ok := m.store.Get(req.APNSToken); ok && existing.Cancel != nil {
		existing.Cancel()
	}
	ctx, cancel := context.WithCancel(context.Background())
	rec := &store.Record{
		APNSToken:  req.APNSToken,
		VoIPToken:  req.VoIPToken,
		LoginToken: req.LoginToken,
		AccountID:  req.AccountID,
		DeviceID:   req.DeviceID,
		IsDev:      req.IsDev,
		Cancel:     cancel,
	}
	m.store.Set(rec)
	go m.runSession(ctx, rec)
	return nil
}

func (m *Manager) UpdateTokens(req RegisterRequest) error {
	if req.APNSToken == "" {
		return errors.New("missing apns_token")
	}
	if !m.store.UpdateTokens(req.APNSToken, req.VoIPToken, req.DeviceID, req.IsDev) {
		return errors.New("not linked")
	}
	return nil
}

func (m *Manager) Unregister(apnsToken string) error {
	rec := m.store.Delete(apnsToken)
	if rec == nil {
		return errors.New("session not found")
	}
	if v, ok := m.sessions.Load(apnsToken); ok {
		if h, ok := v.(*pushHandler); ok && h.client != nil {
			_, _ = h.client.SendRequest(protocol.OpLogout, nil)
		}
	}
	if rec.Cancel != nil {
		rec.Cancel()
	}
	return nil
}

func (m *Manager) SetForeground(apnsToken string, fg bool) error {
	if !m.store.SetForeground(apnsToken, fg) {
		return errors.New("session not found")
	}
	return nil
}

func (m *Manager) SetAvatarColors(apnsToken, lightBg, lightFg, darkBg, darkFg string) error {
	if !m.store.SetAvatarColors(apnsToken, lightBg, lightFg, darkBg, darkFg) {
		return errors.New("session not found")
	}
	return nil
}

// Reply отправляет ответ из уведомления через уже установленную MAX-сессию
// пользователя, не создавая вторую сессию. Сначала помечает чат прочитанным
// (до replyTo/mark), затем шлёт сообщение. Эхо notifMessage от собственного
// сообщения отфильтруется в OnMessage (senderID == rec.AccountID).
func (m *Manager) Reply(apnsToken string, chatID, replyTo, mark int64, text string) error {
	v, ok := m.sessions.Load(apnsToken)
	if !ok {
		return errors.New("session not found")
	}
	h, ok := v.(*pushHandler)
	if !ok || h.client == nil {
		return errors.New("client not ready")
	}
	text = strings.TrimSpace(text)
	if text == "" {
		return errors.New("empty text")
	}
	if replyTo > 0 && mark > 0 {
		markPayload, err := msgpack.Marshal(map[string]interface{}{
			"type":      "READ_MESSAGE",
			"chatId":    chatID,
			"messageId": replyTo,
			"mark":      mark,
		})
		if err == nil {
			if _, err := h.client.SendRequest(protocol.OpChatMark, markPayload); err != nil {
				log.Printf("Reply: chatMark failed for chat %d: %v", chatID, err)
			}
		}
	}
	message := map[string]interface{}{
		"text":     text,
		"cid":      -time.Now().UnixMilli(),
		"elements": []interface{}{},
		"attaches": []interface{}{},
	}
	if replyTo > 0 {
		message["link"] = map[string]interface{}{
			"type":      "REPLY",
			"chatId":    chatID,
			"messageId": replyTo,
		}
	}
	sendPayload, err := msgpack.Marshal(map[string]interface{}{
		"chatId":  chatID,
		"message": message,
		"notify":  true,
	})
	if err != nil {
		return fmt.Errorf("marshal msgSend: %w", err)
	}
	if _, err := h.client.SendRequest(protocol.OpMsgSend, sendPayload); err != nil {
		return fmt.Errorf("msgSend: %w", err)
	}
	return nil
}

func (m *Manager) Verify(req VerifyRequest) VerifyResponse {
	rec, ok := m.store.Get(req.APNSToken)
	if !ok {
		return VerifyResponse{}
	}
	return VerifyResponse{
		Registered:           true,
		VoIPTokenPresent:     rec.VoIPToken != "",
		LoginTokenPresent:    rec.LoginToken != "",
		VoIPTokenMatches:     !req.HasVoIP || rec.VoIPToken == req.VoIPToken,
		AccountIDMatches:     !req.HasAccount || rec.AccountID == req.AccountID,
		DeviceIDMatches:      !req.HasDevice || rec.DeviceID == req.DeviceID,
		IsDevelopmentMatches: !req.HasIsDev || rec.IsDev == req.IsDevelopment,
	}
}

func (m *Manager) runSession(ctx context.Context, rec *store.Record) {
	backoff := initialBackoff
	authFailures := 0
	for {
		select {
		case <-ctx.Done():
			return
		default:
		}
		err := m.connectAndServe(ctx, rec)
		if err == nil {
			authFailures = 0
		} else {
			log.Printf("session %s: %v", rec.APNSToken, err)
			if errors.Is(err, ErrAuthRejected) {
				authFailures++
				if authFailures >= maxAuthFailures {
					log.Printf("session %s: dropping after %d consecutive auth failures (token invalid)", rec.APNSToken, authFailures)
					m.notifyUnlinked(rec)
					m.store.Delete(rec.APNSToken)
					return
				}
			} else {
				authFailures = 0
			}
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
			backoff *= 2
			if backoff > maxBackoff {
				backoff = maxBackoff
			}
		}
	}
}

func (m *Manager) notifyUnlinked(rec *store.Record) {
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]string{
				"title": "Komet",
				"body":  "Уведомления MAX отключены. Привяжите их заново в настройках.",
			},
			"sound": "default",
		},
		"komet-event": "unlinked",
	}
	if err := m.apns.Send(rec.APNSToken, rec.IsDev, payload); err != nil {
		log.Printf("session %s: unlinked push failed: %v", rec.APNSToken, err)
	}
}

func (m *Manager) connectAndServe(ctx context.Context, rec *store.Record) error {
	h := &pushHandler{manager: m, token: rec.APNSToken, isDev: rec.IsDev}
	h.initCaches(rec)
	m.registerSession(rec.APNSToken, h)
	defer m.unregisterSession(rec.APNSToken)
	cli := NewClient(Config{
		Host:       m.maxHost,
		Port:       m.maxPort,
		LoginToken: rec.LoginToken,
		DeviceID:   rec.DeviceID,
	}, h)
	h.client = cli
	if err := cli.Connect(ctx); err != nil {
		return fmt.Errorf("connect: %w", err)
	}
	return cli.Serve(ctx)
}

type pushHandler struct {
	manager     *Manager
	client      *Client
	token       string
	isDev       bool
	names       sync.Map
	avatars     sync.Map
	chats       sync.Map
	chatIcons   sync.Map
	unreadChats sync.Map
	flushTick   *time.Ticker
	flushDone   chan struct{}
}

func (h *pushHandler) initCaches(rec *store.Record) {
	for k, v := range rec.Names {
		h.names.Store(k, v)
	}
	for k, v := range rec.Avatars {
		h.avatars.Store(k, v)
	}
	for k, v := range rec.ChatInfos {
		ci := &ChatInfo{Title: v.Title, IsChat: v.IsChat, IsChannel: v.IsChannel}
		h.chats.Store(k, ci)
	}
	for k, v := range rec.ChatIcons {
		h.chatIcons.Store(k, v)
	}
	for k, v := range rec.UnreadChats {
		h.unreadChats.Store(k, v)
	}
	h.flushTick = time.NewTicker(30 * time.Second)
	h.flushDone = make(chan struct{})
	go h.flushLoop()
}

func (h *pushHandler) flushLoop() {
	for {
		select {
		case <-h.flushDone:
			h.flush()
			return
		case <-h.flushTick.C:
			h.flush()
		}
	}
}

func (h *pushHandler) flush() {
	unread := make(map[int64]int)
	h.unreadChats.Range(func(k, v interface{}) bool {
		unread[k.(int64)] = v.(int)
		return true
	})
	names := make(map[int64]string)
	h.names.Range(func(k, v interface{}) bool {
		names[k.(int64)] = v.(string)
		return true
	})
	avatars := make(map[int64]string)
	h.avatars.Range(func(k, v interface{}) bool {
		avatars[k.(int64)] = v.(string)
		return true
	})
	chatIcons := make(map[int64]string)
	h.chatIcons.Range(func(k, v interface{}) bool {
		chatIcons[k.(int64)] = v.(string)
		return true
	})
	chats := make(map[int64]store.ChatInfoCache)
	h.chats.Range(func(k, v interface{}) bool {
		ci := v.(*ChatInfo)
		chats[k.(int64)] = store.ChatInfoCache{Title: ci.Title, IsChat: ci.IsChat, IsChannel: ci.IsChannel}
		return true
	})
	h.manager.store.UpdateCaches(h.token, unread, names, avatars, chatIcons, chats)
}

func (h *pushHandler) stopFlush() {
	h.flushTick.Stop()
	close(h.flushDone)
}

func (h *pushHandler) OnMessage(chatID, senderID, msgID, msgTime int64, text, msgType, mediaURL string, unread int) {
	rec, ok := h.manager.store.Get(h.token)
	if !ok {
		return
	}
	if rec.Foreground {
		return
	}
	if senderID != 0 && senderID == rec.AccountID {
		return
	}
	if unread <= 0 {
		unread = 1
	}
	h.unreadChats.Store(chatID, unread)
	if text == "" {
		text = typeLabel(msgType, "")
	}
	chatIDStr := fmt.Sprintf("%d", chatID)

	senderName := "Канал"
	if senderID != 0 {
		senderName = h.cachedName(senderID)
	}
	ci := h.cachedChatInfo(chatID)
	if (senderID != 0 && senderName == "Новое сообщение") || ci == nil {
		nameCh := make(chan string, 1)
		ciCh := make(chan *ChatInfo, 1)
		if senderID != 0 {
			go func() { nameCh <- h.fetchName(senderID) }()
		} else {
			nameCh <- "Канал"
		}
		go func() { ciCh <- h.fetchChatInfo(chatID) }()
		timer := time.NewTimer(3 * time.Second)
		for i := 0; i < 2; i++ {
			select {
			case v := <-nameCh:
				senderName = v
				if senderName == "" {
					senderName = "Новое сообщение"
				}
				h.names.Store(senderID, senderName)
			case v := <-ciCh:
				ci = v
				if ci != nil {
					h.chats.Store(chatID, ci)
				}
			case <-timer.C:
				i = 2
			}
		}
		timer.Stop()
	}

	alert := map[string]interface{}{
		"body": text,
	}
	if ci != nil {
		if ci.IsChannel {
			alert["title"] = ci.Title
		} else if ci.IsChat {
			alert["title"] = ci.Title
			alert["subtitle"] = senderName
		} else {
			alert["title"] = senderName
		}
	} else {
		alert["title"] = senderName
	}
	var senderAvatar string
	var chatIcon string
	if senderID != 0 {
		senderAvatar = h.cachedAvatar(senderID)
	}
	if ci != nil && (ci.IsChannel || ci.IsChat) {
		chatIcon = h.cachedChatIcon(chatID)
	}

	aps := map[string]interface{}{
		"alert":           alert,
		"sound":           "default",
		"badge":           h.totalUnread(),
		"thread-id":       chatIDStr,
		"mutable-content": 1,
	}
	payload := map[string]interface{}{
		"aps":    aps,
		"chatId": chatID,
	}
	if displayName, ok := alert["title"].(string); ok {
		payload["komet-name"] = displayName
	}
	isGroup := ci != nil && ci.IsChat
	isChannel := ci != nil && ci.IsChannel
	payload["komet-is-group"] = isGroup
	payload["komet-is-channel"] = isChannel
	if senderID != 0 {
		payload["komet-sender-id"] = fmt.Sprintf("%d", senderID)
		payload["komet-sender-name"] = senderName
	}
	if isChannel || isGroup {
		if chatIcon != "" {
			payload["komet-chat-icon"] = chatIcon
		}
		payload["komet-chat-name"] = ci.Title
	}
	if !isChannel && !isGroup && senderAvatar != "" {
		payload["komet-avatar"] = senderAvatar
	} else if isGroup && senderAvatar != "" {
		payload["komet-avatar"] = senderAvatar
	}
	if msgID != 0 {
		payload["komet-msg-id"] = fmt.Sprintf("%d", msgID)
	}
	if msgTime != 0 {
		payload["komet-msg-time"] = fmt.Sprintf("%d", msgTime)
	}
	if msgType != "" {
		payload["komet-msg-type"] = msgType
	}
	if mediaURL != "" {
		payload["komet-media"] = mediaURL
	}
	h.applyAvatarColors(payload, rec)
	subtitle, _ := alert["subtitle"].(string)
	titleStr, _ := alert["title"].(string)
	badge := h.totalUnread()
	payloadJSON, _ := json.Marshal(payload)
	log.Printf("=== PUSH (legacy session) ===")
	log.Printf("  incoming: chatID=%d senderID=%d text=%q unread=%d", chatID, senderID, text, unread)
	log.Printf("  resolved: title=%q subtitle=%q chatType=%v", titleStr, subtitle, chatTypeStr(ci))
	log.Printf("  badge=%d (totalUnread=%d)", badge, badge)
	log.Printf("  apns payload: %s", string(payloadJSON))
	log.Printf("  → sending to %s env=%s", h.token[:16]+"...", envLabel(h.isDev))
	if err := h.manager.apns.Send(h.token, h.isDev, payload); err != nil {
		log.Printf("  FAILED: %v", err)
	} else {
		log.Printf("  OK")
	}
	log.Printf("=== END ===")

	if senderAvatar == "" && senderID != 0 {
		h.ensureAvatar(senderID)
	}
	if ci != nil && (ci.IsChannel || ci.IsChat) && h.cachedChatIcon(chatID) == "" {
		h.ensureChatIcon(chatID)
	}
}

func typeLabel(msgType, fileName string) string {
	switch msgType {
	case "photo":
		return "Фото"
	case "video":
		return "Видео"
	case "videonote":
		return "Видеосообщение"
	case "voice":
		return "Голосовое сообщение"
	case "file":
		if fileName != "" {
			return "Файл: " + fileName
		}
		return "Файл"
	default:
		return "Сообщение"
	}
}

func chatTypeStr(ci *ChatInfo) string {
	if ci == nil {
		return "unknown"
	}
	if ci.IsChannel {
		return "channel"
	}
	if ci.IsChat {
		return "group"
	}
	return "dialog"
}

func envLabel(isDev bool) string {
	if isDev {
		return "sandbox"
	}
	return "production"
}

func (h *pushHandler) OnMarkRead(chatID int64) {
	h.unreadChats.Delete(chatID)
	chatIDStr := fmt.Sprintf("%d", chatID)
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"badge":     h.totalUnread(),
			"thread-id": chatIDStr,
		},
		"chatId":      chatID,
		"clearChatId": chatID,
	}
	log.Printf("push markRead chatID=%d → apns badge=%d", chatID, h.totalUnread())
	if err := h.manager.apns.Send(h.token, h.isDev, payload); err != nil {
		log.Printf("apns badge clear to %s failed: %v", h.token, err)
	}
}

func (h *pushHandler) OnCallHistory(callerID, chatID int64, hangupType string, durationMs int64) {
	rec, ok := h.manager.store.Get(h.token)
	if !ok {
		return
	}
	if rec.Foreground {
		return
	}
	name := h.cachedName(callerID)
	if name == "" {
		name = "Неизвестный номер"
	}
	avatarURL := h.cachedAvatar(callerID)
	callerIDStr := fmt.Sprintf("%d", callerID)
	aps := map[string]interface{}{
		"alert": map[string]interface{}{
			"title": "Пропущенный звонок",
			"body":  name,
		},
		"sound": "default",
		"badge": 1,
	}
	if avatarURL != "" {
		aps["mutable-content"] = 1
	}
	payload := map[string]interface{}{
		"aps":    aps,
		"chatId": chatID,
		"call":   true,
	}
	payload["komet-name"] = name
	if callerID != 0 {
		payload["komet-sender-id"] = callerIDStr
		payload["komet-sender-name"] = name
	}
	if avatarURL != "" {
		payload["komet-avatar"] = avatarURL
	}
	h.applyAvatarColors(payload, rec)
	log.Printf("push callHistory callerID=%d name=%q hangup=%s → apns", callerID, name, hangupType)
	if err := h.manager.apns.Send(h.token, h.isDev, payload); err != nil {
		log.Printf("apns call history to %s failed: %v", h.token, err)
	}
	h.ensureName(callerID)
	h.ensureAvatar(callerID)
}

func (h *pushHandler) OnCallStart(callerID int64, conversationId, callType, vcp string) {
	rec, ok := h.manager.store.Get(h.token)
	if !ok {
		return
	}
	if rec.Foreground {
		return
	}
	name := h.cachedName(callerID)
	if name == "" {
		name = "Неизвестный номер"
	}
	payload := map[string]interface{}{
		"aps": map[string]interface{}{
			"alert": map[string]interface{}{
				"title": "Входящий звонок",
				"body":  name,
			},
			"sound": "default",
			"badge": 1,
		},
		"call":           true,
		"conversationId": conversationId,
		"callerId":       callerID,
		"isVideo":        callType == "VIDEO",
		"vcp":            vcp,
	}
	voipToken := rec.VoIPToken
	if voipToken != "" {
		log.Printf("push callStart callerID=%d name=%q convId=%s type=%s → apns voip (token=%s...)", callerID, name, conversationId, callType, voipToken[:16])
		if err := h.manager.apns.SendVoIP(voipToken, h.isDev, payload); err != nil {
			log.Printf("apns voip failed, trying apns token: %v", err)
			if err := h.manager.apns.Send(h.token, h.isDev, payload); err != nil {
				log.Printf("apns call start to %s failed: %v", h.token, err)
			}
		}
	} else {
		log.Printf("push callStart callerID=%d name=%q convId=%s type=%s → apns alert (no voip token)", callerID, name, conversationId, callType)
		if err := h.manager.apns.Send(h.token, h.isDev, payload); err != nil {
			log.Printf("apns call start to %s failed: %v", h.token, err)
		}
	}
	h.ensureName(callerID)
}

func (h *pushHandler) applyAvatarColors(payload map[string]interface{}, rec *store.Record) {
	if rec.AvatarLightBg != "" {
		payload["komet-accent-light-bg"] = rec.AvatarLightBg
	}
	if rec.AvatarLightFg != "" {
		payload["komet-accent-light-fg"] = rec.AvatarLightFg
	}
	if rec.AvatarDarkBg != "" {
		payload["komet-accent-dark-bg"] = rec.AvatarDarkBg
	}
	if rec.AvatarDarkFg != "" {
		payload["komet-accent-dark-fg"] = rec.AvatarDarkFg
	}
}

func (h *pushHandler) setUnreadMap(m map[int64]int) {
	h.unreadChats.Range(func(k, _ interface{}) bool {
		h.unreadChats.Delete(k)
		return true
	})
	for k, v := range m {
		if v > 0 {
			h.unreadChats.Store(k, v)
		}
	}
}

func (h *pushHandler) totalUnread() int {
	count := 0
	h.unreadChats.Range(func(_, v interface{}) bool {
		if n, ok := v.(int); ok && n > 0 {
			count += n
		}
		return true
	})
	return count
}

func (h *pushHandler) cachedName(userID int64) string {
	if v, ok := h.names.Load(userID); ok {
		return v.(string)
	}
	return "Новое сообщение"
}

func (h *pushHandler) cachedAvatar(userID int64) string {
	if v, ok := h.avatars.Load(userID); ok {
		return v.(string)
	}
	return ""
}

func (h *pushHandler) cachedChatIcon(chatID int64) string {
	if v, ok := h.chatIcons.Load(chatID); ok {
		return v.(string)
	}
	return ""
}

func (h *pushHandler) ensureName(userID int64) {
	if _, ok := h.names.Load(userID); ok {
		return
	}
	go func() {
		name := h.fetchName(userID)
		if name != "" {
			h.names.Store(userID, name)
			log.Printf("resolved name for %d: %q", userID, name)
		} else {
			log.Printf("resolveName failed for %d", userID)
		}
	}()
}

func (h *pushHandler) ensureAvatar(userID int64) {
	if _, ok := h.avatars.Load(userID); ok {
		return
	}
	go func() {
		h.fetchName(userID)
	}()
}

func (h *pushHandler) fetchName(userID int64) string {
	if h.client == nil {
		log.Printf("fetchName: client is nil for %d", userID)
		return ""
	}
	start := time.Now()
	req, err := msgpack.Marshal(map[string]interface{}{
		"contactIds": []interface{}{userID},
	})
	if err != nil {
		return ""
	}
	resp, err := h.client.SendRequest(protocol.OpContactInfo, req)
	if err != nil {
		log.Printf("fetchName: request failed for %d (%v): %v", userID, time.Since(start), err)
		return ""
	}
	var m map[string]interface{}
	if err := msgpack.Unmarshal(resp.Payload, &m); err != nil {
		log.Printf("fetchName: unmarshal failed for %d: %v", userID, err)
		return ""
	}
	contacts, _ := m["contacts"].([]interface{})
	for _, c := range contacts {
		cm, _ := c.(map[string]interface{})
		if cm == nil {
			continue
		}
		if toInt64(cm["id"]) != userID {
			continue
		}
		if baseUrl, ok := cm["baseUrl"].(string); ok && baseUrl != "" {
			h.avatars.Store(userID, baseUrl)
		}
		names, _ := cm["names"].([]interface{})
		for _, n := range names {
			nm, _ := n.(map[string]interface{})
			if nm == nil {
				continue
			}
			first, _ := nm["firstName"].(string)
			last, _ := nm["lastName"].(string)
			if first != "" && last != "" {
				return first + " " + last
			}
			if first != "" {
				return first
			}
			if name, ok := nm["name"].(string); ok && name != "" {
				return name
			}
		}
		log.Printf("fetchName: contact %d keys: %+v", userID, cm)
	}
	log.Printf("fetchName: no contact match for %d in %d contacts", userID, len(contacts))
	return ""
}

func (h *pushHandler) cachedChatInfo(chatID int64) *ChatInfo {
	if v, ok := h.chats.Load(chatID); ok {
		return v.(*ChatInfo)
	}
	return nil
}

func (h *pushHandler) ensureChatInfo(chatID int64) {
	if _, ok := h.chats.Load(chatID); ok {
		return
	}
	go func() {
		ci := h.fetchChatInfo(chatID)
		if ci != nil {
			h.chats.Store(chatID, ci)
			log.Printf("resolved chat %d: title=%q isChat=%v isChannel=%v", chatID, ci.Title, ci.IsChat, ci.IsChannel)
		} else {
			log.Printf("resolveChat failed for %d", chatID)
		}
	}()
}

func (h *pushHandler) ensureChatIcon(chatID int64) {
	if _, ok := h.chatIcons.Load(chatID); ok {
		return
	}
	go func() {
		h.fetchChatInfo(chatID)
	}()
}

func (h *pushHandler) fetchChatInfo(chatID int64) *ChatInfo {
	if h.client == nil {
		log.Printf("fetchChatInfo: client is nil for %d", chatID)
		return nil
	}
	start := time.Now()
	log.Printf("fetchChatInfo: start for %d", chatID)
	req, err := msgpack.Marshal(map[string]interface{}{
		"chatIds": []interface{}{chatID},
	})
	if err != nil {
		log.Printf("fetchChatInfo: marshal failed for %d: %v", chatID, err)
		return nil
	}
	resp, err := h.client.SendRequest(protocol.OpChatInfo, req)
	if err != nil {
		log.Printf("fetchChatInfo: request failed for %d (%v): %v", chatID, time.Since(start), err)
		return nil
	}
	log.Printf("fetchChatInfo: got response for %d (%v), payloadLen=%d", chatID, time.Since(start), len(resp.Payload))
	ci := parseChatInfoFromRaw(resp.Payload)
	if ci == nil {
		log.Printf("fetchChatInfo: raw parse failed for %d", chatID)
		return nil
	}
	if ci.IconUrl != "" {
		h.chatIcons.Store(chatID, ci.IconUrl)
	}
	log.Printf("fetchChatInfo: resolved %d title=%q type=%q icon=%q hasBaseIconUrlKey=%v (%v)",
		chatID, ci.Title, chatTypeStr(ci), ci.IconUrl, bytes.Contains(resp.Payload, []byte("baseIconUrl")), time.Since(start))
	return ci
}

func parseChatInfoFromRaw(payload []byte) *ChatInfo {
	typeKey := []byte{0xa4, 't', 'y', 'p', 'e'}
	titleKey := []byte{0xa5, 't', 'i', 't', 'l', 'e'}
	iconKey := []byte{0xab, 'b', 'a', 's', 'e', 'I', 'c', 'o', 'n', 'U', 'r', 'l'}
	chatType := findStringAfter(payload, typeKey)
	title := findStringAfter(payload, titleKey)
	iconURL := findStringAfter(payload, iconKey)
	if chatType == "" && title == "" {
		return nil
	}
	return &ChatInfo{
		Title:     title,
		IsChat:    chatType == "CHAT" || chatType == "GROUP",
		IsChannel: chatType == "CHANNEL",
		IconUrl:   iconURL,
	}
}

func findStringAfter(data []byte, key []byte) string {
	idx := bytes.Index(data, key)
	if idx < 0 {
		return ""
	}
	pos := idx + len(key)
	if pos >= len(data) {
		return ""
	}
	return readMsgpackString(data, pos)
}

func readMsgpackString(data []byte, pos int) string {
	if pos >= len(data) {
		return ""
	}
	b := data[pos]
	pos++
	var length int
	if b >= 0xa0 && b <= 0xbf {
		length = int(b & 0x1f)
	} else if b == 0xd9 {
		if pos >= len(data) {
			return ""
		}
		length = int(data[pos])
		pos++
	} else if b == 0xda {
		if pos+1 >= len(data) {
			return ""
		}
		length = int(data[pos])<<8 | int(data[pos+1])
		pos += 2
	} else {
		return ""
	}
	if pos+length > len(data) {
		return ""
	}
	return string(data[pos : pos+length])
}
