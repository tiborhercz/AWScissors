package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ssm"
)

var SsmKeyMsTeamsWebhook = os.Getenv("SSM_KEY_MS_TEAMS_WEBHOOK")

type SnsMessage struct {
	DateTime string `json:"datetime"`
	Message  string `json:"message"`
	Subject  string `json:"subject"`
}

func HandleRequest(ctx context.Context, event events.SNSEvent) {
	var snsMessage SnsMessage
	sess := session.Must(session.NewSessionWithOptions(session.Options{
		SharedConfigState: session.SharedConfigEnable,
	}))

	svc := ssm.New(sess)

	withDecryption := true
	param, err := svc.GetParameter(&ssm.GetParameterInput{
		Name:           &SsmKeyMsTeamsWebhook,
		WithDecryption: &withDecryption,
	})
	if err != nil {
		fmt.Println(err.Error())
		return
	}

	msClient := NewClient()

	_ = json.Unmarshal([]byte(event.Records[0].SNS.Message), &snsMessage)

	eventMessage := snsMessage.Message
	eventTitle := snsMessage.Subject

	err = msClient.Send(*param.Parameter.Value, eventMessage, eventTitle)
	if err != nil {
		fmt.Println(err.Error())
		return
	}
}

func main() {
	lambda.Start(HandleRequest)
}
