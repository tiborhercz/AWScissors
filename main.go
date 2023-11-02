package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sns"
)

var SNS_TOPIC_ARN = os.Getenv("SNS_TOPIC_ARN")

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

func HandleRequest(ctx context.Context, event events.CloudWatchEvent) {
	var eventDetails CloudWatchEventDetails
	fmt.Println(event)

	detail := fmt.Sprintf("Detail = %s\n", event.Detail)
	fmt.Println(detail)

	_ = json.Unmarshal(event.Detail, &eventDetails)

	sessionFromConsoleText := "not from the Management Console"
	if eventDetails.SessionCredentialFromConsole == "true" {
		sessionFromConsoleText = "from the Management Console"
	}

	outputMessage := fmt.Sprintf("AWScissors ✂️ %s on %s in %s by %s %s",
		eventDetails.EventName,
		eventDetails.EventSource,
		eventDetails.UserIdentity.AccountID,
		eventDetails.UserIdentity.Arn,
		sessionFromConsoleText,
	)

	sess := session.Must(session.NewSessionWithOptions(session.Options{
		SharedConfigState: session.SharedConfigEnable,
	}))

	svc := sns.New(sess)

	result, err := svc.Publish(&sns.PublishInput{
		Message:  &outputMessage,
		TopicArn: &SNS_TOPIC_ARN,
	})
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	fmt.Println(*result.MessageId)

	fmt.Println(outputMessage)
}

func main() {
	lambda.Start(HandleRequest)
}
