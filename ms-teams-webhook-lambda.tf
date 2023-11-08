module "go_lambda_packer_teamswebhook" {
  source      = "./modules/go-lambda-packer"
  source_path = "${path.module}/lambda/teamswebhook"
  output_path = "${path.module}/teamswebhook.zip"
}

resource "aws_lambda_function" "ms_teams_webhook" {
  filename         = module.go_lambda_packer_teamswebhook.archive_output_path
  function_name    = "${local.name}-ms-teams-webhook"
  role             = aws_iam_role.ms_teams_webhook.arn
  handler          = "teamswebhook"
  runtime          = "go1.x"
  timeout          = 8
  source_code_hash = module.go_lambda_packer_teamswebhook.source_code_hash

  environment {
    variables = {
      SSM_KEY_MS_TEAMS_WEBHOOK = data.aws_ssm_parameter.teams_webhook_url.name
    }
  }
}

resource "aws_lambda_permission" "ms_teams_webhook" {
  statement_id  = "AllowExecutionFromSns"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ms_teams_webhook.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.aws_scissors_notifications.arn
}

resource "aws_cloudwatch_log_group" "ms_teams_webhook" {
  name              = "/aws/lambda/${aws_lambda_function.ms_teams_webhook.function_name}"
  retention_in_days = 14
}

resource "aws_iam_role" "ms_teams_webhook" {
  name = "${local.name}-ms-teams-webhook"

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

resource "aws_iam_policy" "ms_teams_webhook_policy" {
  name   = "${local.name}-ms-teams-webhook-lambda-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Effect : "Allow",
        Action : "logs:CreateLogGroup",
        Resource : "arn:aws:logs:${local.region}:${local.account_id}:*"
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${aws_lambda_function.ms_teams_webhook.function_name}:*"
      },
      {
        Effect : "Allow",
        Action : [
          "ssm:GetParameter"
        ],
        Resource : aws_ssm_parameter.teams_webhook_url.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ms_teams_webhook" {
  role       = aws_iam_role.ms_teams_webhook.id
  policy_arn = aws_iam_policy.ms_teams_webhook_policy.arn
}

