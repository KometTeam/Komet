package apns

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Client struct {
	prodHost string
	devHost  string
	bundleID string
	jwt      *JWTProvider
	http     *http.Client
}

func NewClient(jwtProvider *JWTProvider, bundleID string) *Client {
	return &Client{
		prodHost: "https://api.push.apple.com",
		devHost:  "https://api.sandbox.push.apple.com",
		bundleID: bundleID,
		jwt:      jwtProvider,
		http:     &http.Client{Timeout: 30 * time.Second},
	}
}

func (c *Client) Send(deviceToken string, isDev bool, payload map[string]interface{}) error {
	return c.send(deviceToken, isDev, payload, "alert", c.bundleID)
}

func (c *Client) SendVoIP(deviceToken string, isDev bool, payload map[string]interface{}) error {
	err := c.send(deviceToken, isDev, payload, "voip", c.bundleID+".voip")
	if err != nil && isNotForTopic(err) {
		fmt.Printf("apns DeviceTokenNotForTopic, voip → alert fallback\n")
		return c.send(deviceToken, isDev, payload, "alert", c.bundleID)
	}
	return err
}

func (c *Client) send(deviceToken string, isDev bool, payload map[string]interface{}, pushType string, topic string) error {
	if deviceToken == "" {
		return fmt.Errorf("empty device token")
	}
	err := c.trySend(deviceToken, isDev, payload, pushType, topic)
	if err != nil && isBadDeviceToken(err) {
		altEnv := !isDev
		fmt.Printf("apns BadDeviceToken, retry %s → %s\n", envName(isDev), envName(altEnv))
		return c.trySend(deviceToken, altEnv, payload, pushType, topic)
	}
	return err
}

func (c *Client) trySend(deviceToken string, isDev bool, payload map[string]interface{}, pushType string, topic string) error {
	host := c.prodHost
	if isDev {
		host = c.devHost
	}
	url := host + "/3/device/" + deviceToken
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("marshal apns payload: %w", err)
	}
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	bearer, err := c.jwt.Token()
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+bearer)
	req.Header.Set("apns-topic", topic)
	req.Header.Set("apns-push-type", pushType)
	resp, err := c.http.Do(req)
	if err != nil {
		return fmt.Errorf("apns request: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("apns error: status=%d body=%s", resp.StatusCode, string(respBody))
	}
	return nil
}

func isBadDeviceToken(err error) bool {
	return strings.Contains(err.Error(), "BadDeviceToken")
}

func isNotForTopic(err error) bool {
	return strings.Contains(err.Error(), "DeviceTokenNotForTopic")
}

func envName(isDev bool) string {
	if isDev {
		return "sandbox"
	}
	return "production"
}
