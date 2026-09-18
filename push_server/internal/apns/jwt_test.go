package apns

import (
	"strings"
	"testing"
)

func TestJWTProviderWithRealKey(t *testing.T) {
	p, err := NewJWTProvider("../../../AuthKey_VU22HULN33.p8", "VU22HULN33", "NS38WF98A9")
	if err != nil {
		t.Fatalf("provider: %v", err)
	}
	tok1, err := p.Token()
	if err != nil {
		t.Fatalf("token: %v", err)
	}
	if !strings.HasPrefix(tok1, "eyJ") {
		t.Fatalf("token does not look like a JWT: %s", tok1)
	}
	tok2, err := p.Token()
	if err != nil {
		t.Fatalf("cached token: %v", err)
	}
	if tok1 != tok2 {
		t.Fatalf("token was not cached")
	}
}
