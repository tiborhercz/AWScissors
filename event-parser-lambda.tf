module "go_lambda_packer_event_parser" {
  source      = "./modules/go-lambda-packer"
  source_path = "${path.module}/lambda/event-parser"
  output_path = "${path.module}/event-parser.zip"
}

resource "aws_lambda_function" "event_parser" {
  filename         = module.go_lambda_packer_event_parser.archive_output_path
  function_name    = "${local.name}-event-parser"
  role             = aws_iam_role.event_parser.arn
  handler          = "event-parser"
  runtime          = "go1.x"
  source_code_hash = module.go_lambda_packer_event_parser.source_code_hash

  environment {
    variables = {
      SNS_TOPIC_ARN        = aws_sns_topic.aws_scissors_notifications.arn
    }
  }
}

resource "aws_lambda_permission" "event_parser" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_parser.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${local.region}:${local.account_id}:rule/${local.name}-*"
}

resource "aws_iam_role" "event_parser" {
  name = "${local.name}-event-parser"

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

resource "aws_iam_policy" "event_parser_policy" {
  name   = "${local.name}-event-parser-lambda-policy"
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
        Resource : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${aws_lambda_function.event_parser.function_name}:*"
      },
      {
        Effect : "Allow",
        Action : "sns:Publish",
        Resource : aws_sns_topic.aws_scissors_notifications.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "event_parser" {
  role       = aws_iam_role.event_parser.id
  policy_arn = aws_iam_policy.event_parser_policy.arn
}

resource "aws_cloudwatch_log_group" "event_parser" {
  name              = "/aws/lambda/${aws_lambda_function.event_parser.function_name}"
  retention_in_days = 14
}
