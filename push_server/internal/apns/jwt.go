package apns

import (
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type JWTProvider struct {
	keyID  string
	teamID string
	key    *ecdsa.PrivateKey
	mu     sync.Mutex
	cached string
	exp    time.Time
}

func NewJWTProvider(keyPath, keyID, teamID string) (*JWTProvider, error) {
	data, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("read apns key: %w", err)
	}
	block, _ := pem.Decode(data)
	if block == nil {
		return nil, fmt.Errorf("apns key is not valid PEM")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse pkcs8 apns key: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("apns key is not ECDSA P-256")
	}
	return &JWTProvider{keyID: keyID, teamID: teamID, key: key}, nil
}

func (p *JWTProvider) Token() (string, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	if p.cached != "" && time.Now().Before(p.exp.Add(-5*time.Minute)) {
		return p.cached, nil
	}
	now := time.Now()
	claims := jwt.RegisteredClaims{
		Issuer:    p.teamID,
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(time.Hour)),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = p.keyID
	signed, err := token.SignedString(p.key)
	if err != nil {
		return "", fmt.Errorf("sign jwt: %w", err)
	}
	p.cached = signed
	p.exp = now.Add(time.Hour)
	return signed, nil
}
