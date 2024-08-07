SLACK_WEBHOOK_URL_FILE=.slackwebhookurl
SLACK_WEBHOOK_URL=`cat $(SLACK_WEBHOOK_URL_FILE)`

update-lambda-code:
	docker run -v $(PWD):/app aws-cfn-update lambda-inline-code --resource Function --file app/main.py app/template.yaml

deploy-cfn:
	aws cloudformation deploy --region us-east-1 --capabilities CAPABILITY_NAMED_IAM --template-file template.yaml --stack-name AWScissors --parameter-overrides SlackwebhookUrl=$(SLACK_WEBHOOK_URL) --parameter-overrides AccountNameList=12345678911=account1,12345678912=account2,12345678913=account3

build-deploy:
	make update-lambda-code
	make deploy-cfn
