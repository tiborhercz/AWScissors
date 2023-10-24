package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"time"
)

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
	EventSource string `json:"eventSource"`
}

func HandleRequest(ctx context.Context, event events.CloudWatchEvent) (*string, error) {
	var eventDetails CloudWatchEventDetails
	fmt.Println(event)

	detail := fmt.Sprintf("Detail = %s\n", event.Detail)
	fmt.Println(detail)

	_ = json.Unmarshal(event.Detail, &eventDetails)

	outputMessage := fmt.Sprintf("AWScissors ✂️ %s on %s in %s by %s", eventDetails.EventName, eventDetails.EventSource, eventDetails.UserIdentity.AccountID, eventDetails.UserIdentity.Arn)
	fmt.Println(outputMessage)

	message := fmt.Sprintf("Hello %s!", event.Source)
	return &message, nil
}

func main() {
	lambda.Start(HandleRequest)
}
