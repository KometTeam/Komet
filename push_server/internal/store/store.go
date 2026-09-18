package store

import (
	"context"
	"encoding/json"
	"os"
	"sync"
)

type ChatInfoCache struct {
	Title     string `json:"title"`
	IsChat    bool   `json:"is_chat"`
	IsChannel bool   `json:"is_channel"`
}

type Record struct {
	APNSToken     string
	VoIPToken     string
	LoginToken    string
	AccountID     int64
	DeviceID      string
	IsDev         bool
	Foreground    bool
	UnreadChats   map[int64]int
	Names         map[int64]string
	Avatars       map[int64]string
	ChatIcons     map[int64]string
	ChatInfos     map[int64]ChatInfoCache
	AvatarLightBg string
	AvatarLightFg string
	AvatarDarkBg  string
	AvatarDarkFg  string
	Cancel        context.CancelFunc `json:"-"`
}

type persistRecord struct {
	APNSToken     string                  `json:"apns_token"`
	VoIPToken     string                  `json:"voip_token,omitempty"`
	LoginToken    string                  `json:"login_token"`
	AccountID     int64                   `json:"account_id"`
	DeviceID      string                  `json:"device_id"`
	IsDev         bool                    `json:"is_dev"`
	UnreadChats   map[int64]int           `json:"unread_chats,omitempty"`
	Names         map[int64]string        `json:"names,omitempty"`
	Avatars       map[int64]string        `json:"avatars,omitempty"`
	ChatIcons     map[int64]string        `json:"chat_icons,omitempty"`
	ChatInfos     map[int64]ChatInfoCache `json:"chat_infos,omitempty"`
	AvatarLightBg string                  `json:"avatar_light_bg,omitempty"`
	AvatarLightFg string                  `json:"avatar_light_fg,omitempty"`
	AvatarDarkBg  string                  `json:"avatar_dark_bg,omitempty"`
	AvatarDarkFg  string                  `json:"avatar_dark_fg,omitempty"`
}

type Store struct {
	mu      sync.Mutex
	records map[string]*Record
	path    string
}

func New(path string) *Store {
	s := &Store{
		records: make(map[string]*Record),
		path:    path,
	}
	s.load()
	return s
}

func (s *Store) Set(r *Record) {
	s.mu.Lock()
	s.records[r.APNSToken] = r
	s.mu.Unlock()
	s.save()
}

func (s *Store) Get(token string) (*Record, bool) {
	s.mu.Lock()
	r, ok := s.records[token]
	s.mu.Unlock()
	return r, ok
}

func (s *Store) Delete(token string) *Record {
	s.mu.Lock()
	r, ok := s.records[token]
	if ok {
		delete(s.records, token)
	}
	s.mu.Unlock()
	if !ok {
		return nil
	}
	s.save()
	return r
}

func (s *Store) UpdateTokens(token, voipToken, deviceID string, isDev bool) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.records[token]
	if !ok {
		return false
	}
	r.VoIPToken = voipToken
	r.DeviceID = deviceID
	r.IsDev = isDev
	s.save()
	return true
}

func (s *Store) SetForeground(token string, fg bool) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	r, ok := s.records[token]
	if !ok {
		return false
	}
	r.Foreground = fg
	return true
}

func (s *Store) SetAvatarColors(token, lightBg, lightFg, darkBg, darkFg string) bool {
	s.mu.Lock()
	r, ok := s.records[token]
	if !ok {
		s.mu.Unlock()
		return false
	}
	r.AvatarLightBg = lightBg
	r.AvatarLightFg = lightFg
	r.AvatarDarkBg = darkBg
	r.AvatarDarkFg = darkFg
	s.mu.Unlock()
	s.save()
	return true
}

func (s *Store) SetUnreadChats(token string, m map[int64]int) bool {
	s.mu.Lock()
	r, ok := s.records[token]
	if !ok {
		s.mu.Unlock()
		return false
	}
	r.UnreadChats = m
	s.mu.Unlock()
	s.save()
	return true
}

func (s *Store) All() []*Record {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]*Record, 0, len(s.records))
	for _, r := range s.records {
		out = append(out, r)
	}
	return out
}

func (s *Store) UpdateCaches(token string, unread map[int64]int, names map[int64]string, avatars map[int64]string, chatIcons map[int64]string, chats map[int64]ChatInfoCache) {
	s.mu.Lock()
	r, ok := s.records[token]
	if !ok {
		s.mu.Unlock()
		return
	}
	r.UnreadChats = unread
	r.Names = names
	r.Avatars = avatars
	r.ChatIcons = chatIcons
	r.ChatInfos = chats
	s.mu.Unlock()
	s.save()
}

func (s *Store) load() {
	data, err := os.ReadFile(s.path)
	if err != nil {
		return
	}
	var prs []persistRecord
	if err := json.Unmarshal(data, &prs); err != nil {
		return
	}
	for _, pr := range prs {
		r := &Record{
			APNSToken:     pr.APNSToken,
			VoIPToken:     pr.VoIPToken,
			LoginToken:    pr.LoginToken,
			AccountID:     pr.AccountID,
			DeviceID:      pr.DeviceID,
			IsDev:         pr.IsDev,
			UnreadChats:   pr.UnreadChats,
			Names:         pr.Names,
			Avatars:       pr.Avatars,
			ChatIcons:     pr.ChatIcons,
			ChatInfos:     pr.ChatInfos,
			AvatarLightBg: pr.AvatarLightBg,
			AvatarLightFg: pr.AvatarLightFg,
			AvatarDarkBg:  pr.AvatarDarkBg,
			AvatarDarkFg:  pr.AvatarDarkFg,
		}
		if r.UnreadChats == nil {
			r.UnreadChats = make(map[int64]int)
		}
		if r.Names == nil {
			r.Names = make(map[int64]string)
		}
		if r.Avatars == nil {
			r.Avatars = make(map[int64]string)
		}
		if r.ChatIcons == nil {
			r.ChatIcons = make(map[int64]string)
		}
		if r.ChatInfos == nil {
			r.ChatInfos = make(map[int64]ChatInfoCache)
		}
		s.records[pr.APNSToken] = r
	}
}

func (s *Store) save() {
	s.mu.Lock()
	prs := make([]persistRecord, 0, len(s.records))
	for _, r := range s.records {
		prs = append(prs, persistRecord{
			APNSToken:     r.APNSToken,
			VoIPToken:     r.VoIPToken,
			LoginToken:    r.LoginToken,
			AccountID:     r.AccountID,
			DeviceID:      r.DeviceID,
			IsDev:         r.IsDev,
			UnreadChats:   r.UnreadChats,
			Names:         r.Names,
			Avatars:       r.Avatars,
			ChatIcons:     r.ChatIcons,
			ChatInfos:     r.ChatInfos,
			AvatarLightBg: r.AvatarLightBg,
			AvatarLightFg: r.AvatarLightFg,
			AvatarDarkBg:  r.AvatarDarkBg,
			AvatarDarkFg:  r.AvatarDarkFg,
		})
	}
	s.mu.Unlock()

	data, err := json.Marshal(prs)
	if err != nil {
		return
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0644); err != nil {
		return
	}
	os.Rename(tmp, s.path)
}
