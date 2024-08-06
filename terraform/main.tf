provider "aws" {
  region = "us-east-1" // IAM is located in the us-east-1 region
}

locals {
  name       = "AWScissors"
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

resource "aws_cloudwatch_event_bus" "awscissors" {
  name = "AWScissors"
}

#module "event-rule" {
#  for_each = toset(var.regions)
#
#  source = "./modules/event-rule"
#
#  name = local.name
#  eventbus_region    = each.value
#  eventbus_arn       = aws_cloudwatch_event_bus.awscissors.arn
#  event_pattern_json = jsonencode({
#    "detail" : {
#      "readOnly" : [false],
#      "userIdentity" : {
#        "type" : ["IAMUser"]
#      }
#    }
#  })
#}

resource "aws_cloudwatch_event_target" "root" {
  arn  = aws_lambda_function.event_parser.arn
  rule = aws_cloudwatch_event_rule.root.id
}

resource "aws_cloudwatch_event_rule" "root" {
  name           = "${local.name}-root"
  description    = "Capture each write/update event for the root user"
  event_bus_name = "default"

  event_pattern = jsonencode({
    "detail" : {
      "readOnly" : [false],
      "userIdentity" : {
        "type" : ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "iam_user" {
  arn  = aws_lambda_function.event_parser.arn
  rule = aws_cloudwatch_event_rule.iam_user.id
}

resource "aws_cloudwatch_event_rule" "iam_user" {
  name           = "${local.name}-iam-user"
  description    = "Capture each write/update event for IAM users"
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
  arn  = aws_lambda_function.event_parser.arn
  rule = aws_cloudwatch_event_rule.assumed_role.id
}

resource "aws_cloudwatch_event_rule" "assumed_role" {
  name           = "${local.name}-assumed-role"
  description    = "Capture each write/update event for SSO users"
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

resource "aws_ssm_parameter" "teams_webhook_url" {
  name        = "/custom/AWScissors/MicrosoftTeamsWebhookUrl"
  description = "The Webhook url for the teams channel. Replace the value with the Teams Webhook Url from your channel."
  type        = "SecureString"
  value       = "TEMPURL"

  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "teams_webhook_url" {
  name = aws_ssm_parameter.teams_webhook_url.name
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
        "arn:aws:lambda:${local.region}:${local.account_id}:function:${aws_lambda_function.event_parser.function_name}"
      ]
    }
  }
}

resource "aws_sns_topic_subscription" "ms_teams_webhook" {
  topic_arn = aws_sns_topic.aws_scissors_notifications.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ms_teams_webhook.arn
}
