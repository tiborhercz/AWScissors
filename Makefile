build:
	GOOS=linux GOARCH=amd64 go build -tags lambda.norpc -o AWScissors main.go

update-function:
	export AWS_REGION=us-east-1 && aws lambda update-function-code --function-name  AWScissors --zip-file fileb://lambda_function.zip

full-deploy:
	rm -f AWScissors lambda_function.zip
	make build
	zip lambda_function.zip AWScissors
	make update-function
