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

var SnsTopicArn = os.Getenv("SNS_TOPIC_ARN")

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

type SnsMessage struct {
	DateTime string `json:"datetime"`
	Message  string `json:"message"`
	Subject  string `json:"subject"`
}

func HandleRequest(ctx context.Context, event events.CloudWatchEvent) {
	var eventDetails CloudWatchEventDetails
	fmt.Println(string(event.Detail))

	sess := session.Must(session.NewSessionWithOptions(session.Options{
		SharedConfigState: session.SharedConfigEnable,
	}))

	_ = json.Unmarshal(event.Detail, &eventDetails)

	outputMessage := fmt.Sprintf("✂️ **%s** on **%s** in **%s** **%s** by **%s** %s",
		eventDetails.EventName,
		eventDetails.EventSource,
		eventDetails.AwsRegion,
		eventDetails.UserIdentity.AccountID,
		eventDetails.UserIdentity.Arn,
		fromConsoleText(eventDetails.SessionCredentialFromConsole),
	)

	snsMessage, err := json.Marshal(SnsMessage{
		Subject:  "AWScissors",
		Message:  outputMessage,
		DateTime: time.Now().Format(time.RFC3339),
	})
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	svc := sns.New(sess)

	message := string(snsMessage)

	result, err := svc.Publish(&sns.PublishInput{
		Message:  &message,
		TopicArn: &SnsTopicArn,
	})
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	fmt.Println(outputMessage)
	fmt.Printf("Message sent to SNS with messageId: %s \n", *result.MessageId)
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
