package teamswebhook

import (
	"bytes"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	WebhookUrlDomain = "webhook.office.com"
)

type API interface {
	Send(webhookUrl string, message string) error
}

type teamsClient struct {
	httpClient *http.Client
}

func NewClient() API {
	client := teamsClient{
		httpClient: &http.Client{
			Timeout: 3 * time.Second,
		},
	}

	return &client
}

func (c teamsClient) Send(webhookUrl string, message string) error {
	if valid, err := validateWebhookUrl(webhookUrl); !valid {
		return fmt.Errorf(err.Error())
	}

	messageBuffer := bytes.NewBuffer([]byte(message))

	req, _ := http.NewRequest(http.MethodPost, webhookUrl, messageBuffer)
	req.Header.Add("Content-Type", "application/json;charset=utf-8")

	_, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf(err.Error())
	}

	return nil
}

func validateWebhookUrl(webhookUrl string) (bool, error) {
	if !strings.Contains(webhookUrl, WebhookUrlDomain) {
		return false, fmt.Errorf(fmt.Sprintf("Url does not have the %s prefix", WebhookUrlDomain))
	}

	return true, nil
}
