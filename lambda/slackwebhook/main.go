package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/events"
	"github.com/slack-go/slack"
)

var SlackToken = os.Getenv("SLACK_OATH_TOKEN")
var SlackChannelId = os.Getenv("CHANNEL_ID")

type CloudWatchEventDetails struct {
	EventVersion     string    `json:"eventVersion"`
	EventID          string    `json:"eventID"`
	EventTime        time.Time `json:"eventTime"`
	EventType        string    `json:"eventType"`
	ResponseElements struct {
		OwnerID      string `json:"ownerId"`
		InstancesSet struct {
			Items []struct {
				InstanceID string `json:"instanceId"`
			} `json:"items"`
		} `json:"instancesSet"`
	} `json:"responseElements"`
	AwsRegion    string `json:"awsRegion"`
	EventName    string `json:"eventName"`
	UserIdentity struct {
		UserName    string `json:"userName"`
		PrincipalID string `json:"principalId"`
		AccessKeyID string `json:"accessKeyId"`
		InvokedBy   string `json:"invokedBy"`
		Type        string `json:"type"`
		Arn         string `json:"arn"`
		AccountID   string `json:"accountId"`
	} `json:"userIdentity"`
	EventSource                  string `json:"eventSource"`
	SessionCredentialFromConsole string `json:"sessionCredentialFromConsole"`
}

var AccountNames = map[string]string{
	"123": "example",
}

func HandleRequest(ctx context.Context, event events.CloudWatchEvent) {
	var eventDetails CloudWatchEventDetails
	fmt.Println(string(event.Detail))

	_ = json.Unmarshal(event.Detail, &eventDetails)

	outputMessage := fmt.Sprintf("✂️ *%s* on *%s* in *%s* of account *%s* (%s) by *%s* %s",
		eventDetails.EventName,
		eventDetails.EventSource,
		eventDetails.AwsRegion,
		AccountNames[eventDetails.UserIdentity.AccountID],
		eventDetails.UserIdentity.AccountID,
		eventDetails.UserIdentity.Arn,
		fromConsoleText(eventDetails.SessionCredentialFromConsole),
	)

	slackApi := slack.New(SlackToken)

	ChannelID, timestamp, err := slackApi.PostMessage(
		SlackChannelId,
		slack.MsgOptionText(outputMessage, false),
		slack.MsgOptionPostMessageParameters(slack.PostMessageParameters{Markdown: true}))
	if err != nil {
		fmt.Printf("%s\n", err)
		return
	}

	ChannelID, timestamp, err = slackApi.PostMessage(
		SlackChannelId,
		slack.MsgOptionText(generateCloudTrailUrl(eventDetails.AwsRegion, eventDetails.EventID), false),
		slack.MsgOptionPostMessageParameters(slack.PostMessageParameters{Markdown: true, ThreadTimestamp: timestamp}))
	if err != nil {
		fmt.Printf("%s\n", err)
		return
	}

	fmt.Println(outputMessage)
	fmt.Printf("Message sent to %s channel at %s \n", ChannelID, timestamp)
}

func generateCloudTrailUrl(region string, eventId string) string {
	return fmt.Sprintf(
		`
Takes a few seconds up to a few minutes for this URL to become active
https://%s.console.aws.amazon.com/cloudtrailv2/home?region=%s#/events/%s`,
		region,
		region,
		eventId)
}

func fromConsoleText(sessionCredentialFromConsole string) string {
	sessionFromConsoleText := "not from the Management Console"
	if sessionCredentialFromConsole == "true" {
		sessionFromConsoleText = "from the Management Console"
	}

	return sessionFromConsoleText
}

func main() {
	lambda.Start(HandleRequest)
}
