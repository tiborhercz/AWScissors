provider "aws" {
  region = "us-east-1" // IAM is located in the us-east-1 region
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

resource "aws_cloudwatch_event_target" "iam_user" {
  arn  = aws_lambda_function.aws_scissors.arn
  rule = aws_cloudwatch_event_rule.iam_user.id
}

resource "aws_cloudwatch_event_rule" "iam_user" {
  name        = "aws_scissors_iam_user"
  description = "Capture each IAMUser event"

  event_pattern = jsonencode({
    "detail" : {
      "userIdentity": {
        "type": ["IAMUser"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "assumed_role" {
  arn  = aws_lambda_function.aws_scissors.arn
  rule = aws_cloudwatch_event_rule.assumed_role.id
}

resource "aws_cloudwatch_event_rule" "assumed_role" {
  name        = "aws_scissors_assumed_role"
  description = "Capture each AssumeRole event"

  event_pattern = jsonencode({
#    "source" : [
#      "aws.sts"
#    ],
#    "detail-type" = [
#      "AWS Console Sign In via CloudTrail"
#    ],
    "detail" : {
#      "eventSource" : ["sts.amazonaws.com"],
#      "eventName" : ["AssumeRole"]
      "userIdentity": {
        "type": ["AssumedRole"],
        "arn" : ["arn:aws:sts::*:assumed-role/AWSReservedSSO_*"]
      }
    }
  })
}

resource "aws_lambda_function" "aws_scissors" {
  filename      = "lambda_function.zip"
  function_name = "AWScissors"
  role          = aws_iam_role.aws_scissors.arn
  handler       = "AWScissors"
  runtime       = "go1.x"
}

resource "aws_lambda_permission" "aws_scissors" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aws_scissors.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${local.region}:${local.account_id}:rule/aws_scissors_*"
}

resource "aws_iam_role" "aws_scissors" {
  name = "AWScissors"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aws_scissors_logging" {
  name   = "aws_scissors_logging"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/AWScissors:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_scissors_logging" {
  role       = aws_iam_role.aws_scissors.id
  policy_arn = aws_iam_policy.aws_scissors_logging.arn
}

resource "aws_cloudwatch_log_group" "aws_scissors" {
  name              = "/aws/lambda/AWScissors"
  retention_in_days = 14
}
