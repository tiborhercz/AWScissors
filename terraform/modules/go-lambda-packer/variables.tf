variable "source_path" {
  description = "Path to root of Go source."
  type        = string
}

variable "output_path" {
  description = "Path for output file."
  type        = string
}

variable "architecture" {
  description = "CPU architecture to compile for."
  type        = string
  default = "amd64"
}

variable "install_dependencies" {
  description = "Install module dependencies."
  type        = bool
  default     = true
}

