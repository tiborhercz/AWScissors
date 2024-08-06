# https://github.com/bschaatsbergen/terraform-go-aws-lambda/blob/main/README.md

data "external" "go_lambda_packer" {
  program = ["bash", "${path.module}/scripts/go_lambda_packer.sh"]

  query = {
    architecture         = var.architecture
    source_path          = var.source_path
    output_path          = var.output_path
    install_dependencies = var.install_dependencies
  }
}

data "archive_file" "zip" {
  type        = "zip"
  source_file  = data.external.go_lambda_packer.result.binary_path
  output_path = var.output_path
}
