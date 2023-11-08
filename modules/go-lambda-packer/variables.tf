variable "source_path" {
  description = "Path to root of Go source."
  type        = string
}

variable "output_path" {
  description = "Path for output file."
  type        = string
}

variable "install_dependencies" {
  description = "Install module dependencies."
  type        = bool
  default     = true
}

