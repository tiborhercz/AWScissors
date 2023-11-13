package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/organizations"
	"github.com/aws/aws-sdk-go/service/sns"
)

var SnsTopicArn = os.Getenv("SNS_TOPIC_ARN")
var InAwsOrganization = os.Getenv("IN_AWS_ORGANIZATION")

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

var accountAliases = make(map[string]string)

var AwsSession = session.Must(session.NewSessionWithOptions(session.Options{
	SharedConfigState: session.SharedConfigEnable,
}))

func init() {
	if len(accountAliases) == 0 {
		initAccountAliases()
		fmt.Println(accountAliases)
	}
}

func HandleRequest(ctx context.Context, event events.CloudWatchEvent) {
	var eventDetails CloudWatchEventDetails
	fmt.Println(string(event.Detail))

	_ = json.Unmarshal(event.Detail, &eventDetails)

	outputMessage := fmt.Sprintf("✂️ **%s** on **%s** in **%s** of account %s (%s) by **%s** %s",
		eventDetails.EventName,
		eventDetails.EventSource,
		eventDetails.AwsRegion,
		fmt.Sprintf("**%s**", getAccountAlias(eventDetails.UserIdentity.AccountID)),
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

	svc := sns.New(AwsSession)

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

func initAccountAliases() {
	inAwsOrganization, err := strconv.ParseBool(InAwsOrganization)
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	if !inAwsOrganization {
		return
	}

	svc := organizations.New(AwsSession)

	response, err := svc.ListAccounts(&organizations.ListAccountsInput{})
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	accounts := response.Accounts
	for {
		if response.NextToken == nil {
			break
		}

		response, _ := svc.ListAccounts(&organizations.ListAccountsInput{NextToken: response.NextToken})
		accounts = append(accounts, response.Accounts...)
	}

	for _, account := range accounts {
		accountAliases[*account.Id] = *account.Name
	}

	return
}

func getAccountAlias(accountId string) string {
	alias, ok := accountAliases[accountId]
	if !ok {
		_ = fmt.Errorf("no account alias found for account ID %s", accountId)
		return ""
	}

	return alias
}

func main() {
	lambda.Start(HandleRequest)
}
