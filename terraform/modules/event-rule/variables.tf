variable "name" {
  description = "Name of the application."
  type        = string
}

variable "eventbus_region" {
  description = "Region the eventbus is located."
  type        = string
}

variable "eventbus_arn" {
  description = "Eventbus to send event to."
  type        = string
}

variable "event_rule_description" {
  description = "Description of the event rule"
  type        = string
}

variable "event_pattern_json" {
  description = "Event pattern in JSON format. Use the jsonencode function for this."
  type        = string
}
