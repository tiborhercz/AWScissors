package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	WebhookUrlDomain = "webhook.office.com"
)

type API interface {
	Send(webhookUrl string, message string, title string) error
}

type teamsClient struct {
	httpClient *http.Client
}

type MessageCard struct {
	Type    string
	Context string
	Title   string
	Text    string
}

func (msg *MessageCard) fillDefaults() {
	msg.Type = "MessageCard"
	msg.Context = "https://schema.org/extensions"
}

func NewClient() API {
	client := teamsClient{
		httpClient: &http.Client{
			Timeout: 3 * time.Second,
		},
	}

	return &client
}

func (c teamsClient) Send(webhookUrl string, message string, title string) error {
	if valid, err := validateWebhookUrl(webhookUrl); !valid {
		fmt.Println(err)
		return fmt.Errorf(err.Error())
	}

	msgCard := MessageCard{}

	msgCard.fillDefaults()
	msgCard.Title = title
	msgCard.Text = message

	webhookMessageByte, _ := json.Marshal(msgCard)
	messageBuffer := bytes.NewBuffer(webhookMessageByte)

	req, _ := http.NewRequest(http.MethodPost, webhookUrl, messageBuffer)
	req.Header.Add("Content-Type", "application/json;charset=utf-8")

	res, err := c.httpClient.Do(req)
	if err != nil {
		fmt.Println(err)
		return fmt.Errorf(err.Error())
	}

	fmt.Println(res)

	return nil
}

func validateWebhookUrl(webhookUrl string) (bool, error) {
	if !strings.Contains(webhookUrl, WebhookUrlDomain) {
		return false, fmt.Errorf(fmt.Sprintf("Url does not have the %s prefix", WebhookUrlDomain))
	}

	return true, nil
}
