package main

import (
	"log"
	"net/http"
	"os"
	"strconv"
	"time"

	"push_server/internal/api"
	"push_server/internal/apns"
	"push_server/internal/link"
	"push_server/internal/session"
	"push_server/internal/store"
)

func main() {
	host := envOr("PUSH_HOST", "0.0.0.0")
	port := envOr("PUSH_PORT", "18029")
	maxHost := envOr("MAX_HOST", "api2.oneme.ru")
	maxPort := envOr("MAX_PORT", "443")
	keyPath := envOr("APNS_KEY_PATH", "./AuthKey_VU22HULN33.p8")
	keyID := envOr("APNS_KEY_ID", "VU22HULN33")
	teamID := envOr("APNS_TEAM_ID", "NS38WF98A9")
	bundleID := envOr("APNS_BUNDLE_ID", "pw.komet.app")
	tlsCert := envOr("TLS_CERT_PATH", "")
	tlsKey := envOr("TLS_KEY_PATH", "")
	dataPath := envOr("DATA_PATH", "/data/sessions.json")

	jwtProvider, err := apns.NewJWTProvider(keyPath, keyID, teamID)
	if err != nil {
		log.Fatalf("apns jwt: %v", err)
	}
	apnsClient := apns.NewClient(jwtProvider, bundleID)
	st := store.New(dataPath)
	mgr := session.NewManager(st, apnsClient, maxHost, mustAtoi(maxPort, 443))
	mgr.Restore()
	log.Printf("restored %d sessions from %s", len(st.All()), dataPath)

	links := link.NewManager(mgr, maxHost, mustAtoi(maxPort, 443))
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			links.Cleanup()
		}
	}()

	h := api.NewHandler(mgr, st, links)
	mux := http.NewServeMux()
	h.Routes(mux)

	addr := host + ":" + port
	if tlsCert != "" && tlsKey != "" {
		log.Printf("push server listening on %s (https, max=%s:%s)", addr, maxHost, maxPort)
		if err := http.ListenAndServeTLS(addr, tlsCert, tlsKey, mux); err != nil {
			log.Fatalf("server: %v", err)
		}
	} else {
		log.Printf("push server listening on %s (http, max=%s:%s)", addr, maxHost, maxPort)
		if err := http.ListenAndServe(addr, mux); err != nil {
			log.Fatalf("server: %v", err)
		}
	}
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func mustAtoi(s string, def int) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	return n
}
