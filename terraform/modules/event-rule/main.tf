provider "aws" {
  region = var.eventbus_region
}

resource "aws_cloudwatch_event_target" "root" {
  rule = aws_cloudwatch_event_rule.rule.id
  arn  = var.eventbus_arn
}

resource "aws_cloudwatch_event_rule" "rule" {
  name           = "${var.name}-root"
  description    = var.event_rule_description
  event_bus_name = "default"

  event_pattern = var.event_pattern_json
}
