terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "lambda_function" {
  source = "../.."

  function_name = "my-function"
  handler       = "main.handler"
  memory_size   = 1024
  timeout       = 60

  # First package, uploaded by Terraform. Build it once with build.sh.
  seed_zip_path = "${path.module}/seed/bootstrap.zip"

  # Use layers only for compiled binaries. Replace with your own ARN.
  layers = [
    "arn:aws:lambda:us-east-1:111122223333:layer:my-layer:1",
  ]

  environment_variables = {
    LOG_LEVEL = "INFO"
  }

  # Least-privilege example. Replace the resources with your own.
  execution_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadDocuments"
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::my-documents-bucket/*"
    }]
  })

  github_repository = "my-org/my-repo"
  github_subjects   = ["environment:main"]

  # Set true only if the account has no GitHub OIDC provider yet.
  create_oidc_provider = false

  human_role_names = ["my-platform-admin-role"]

  tags = {
    Application = "my-app"
    Owner       = "platform"
  }
}

output "function_arn" {
  value = module.lambda_function.function_arn
}

output "artifact_bucket" {
  value = module.lambda_function.artifact_bucket
}

output "deploy_role_arn" {
  value = module.lambda_function.deploy_role_arn
}
