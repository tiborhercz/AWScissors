provider "aws" {
  region = "us-east-1" // IAM is located in the us-east-1 region
}

locals {
  name       = "AWScissors"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

resource "aws_cloudwatch_event_target" "iam_user" {
  arn  = aws_lambda_function.aws_scissors.arn
  rule = aws_cloudwatch_event_rule.iam_user.id
}

resource "aws_cloudwatch_event_rule" "iam_user" {
  name           = "${local.name}-iam-user"
  description    = "Capture each IAMUser event"
  event_bus_name = "default"

  event_pattern = jsonencode({
    "detail" : {
      "readOnly" : [false],
      "userIdentity" : {
        "type" : ["IAMUser"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "assumed_role" {
  arn  = aws_lambda_function.aws_scissors.arn
  rule = aws_cloudwatch_event_rule.assumed_role.id
}

resource "aws_cloudwatch_event_rule" "assumed_role" {
  name           = "${local.name}-assumed-role"
  description    = "Capture each AssumeRole event"
  event_bus_name = "default"

  event_pattern = jsonencode({
    "detail" : {
      "readOnly" : [false],
      "userIdentity" : {
        "type" : ["AssumedRole"],
        "arn" : [
          {
            "wildcard" : "arn:aws:sts::*:assumed-role/AWSReservedSSO_*"
          }
        ]
      }
    }
  })
}

resource "aws_lambda_function" "aws_scissors" {
  filename      = "lambda_function.zip"
  function_name = local.name
  role          = aws_iam_role.aws_scissors.arn
  handler       = "AWScissors"
  runtime       = "go1.x"
  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.aws_scissors_notifications.arn
    }
  }
}

resource "aws_lambda_permission" "aws_scissors" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.aws_scissors.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${local.region}:${local.account_id}:rule/${local.name}-*"
}

resource "aws_iam_role" "aws_scissors" {
  name = local.name

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aws_scissors_policy" {
  name   = "${local.name}-lambda-policy"
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
        Resource : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.name}:*"
      },
      {
        "Sid" : "PublishSNSMessage",
        "Effect" : "Allow",
        "Action" : "sns:Publish",
        "Resource" : aws_sns_topic.aws_scissors_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_scissors_logging" {
  role       = aws_iam_role.aws_scissors.id
  policy_arn = aws_iam_policy.aws_scissors_policy.arn
}

resource "aws_cloudwatch_log_group" "aws_scissors" {
  name              = "/aws/lambda/${local.name}"
  retention_in_days = 14
}

resource "aws_sns_topic" "aws_scissors_notifications" {
  name = "${local.name}-notifications"
}

resource "aws_sns_topic_policy" "aws_scissors_notifications" {
  arn = aws_sns_topic.aws_scissors_notifications.arn

  policy = data.aws_iam_policy_document.aws_scissors_notifications.json
}

data "aws_iam_policy_document" "aws_scissors_notifications" {
  policy_id = "${local.name}-notifications"

  statement {
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    effect = "Allow"

    actions = [
      "SNS:Publish"
    ]

    resources = [
      aws_sns_topic.aws_scissors_notifications.arn,
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.name}"
      ]
    }
  }
}
