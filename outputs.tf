output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "artifact_bucket" {
  description = "Artifact bucket name. Set this as ARTIFACT_BUCKET in the pipeline."
  value       = aws_s3_bucket.artifacts.id
}

output "execution_role_arn" {
  description = "Execution role of the function."
  value       = aws_iam_role.exec.arn
}

output "deploy_role_arn" {
  description = "Role for GitHub Actions. Set this as AWS_DEPLOY_ROLE_ARN in the GitHub Environment."
  value       = aws_iam_role.deploy.arn
}

output "reference_mode_applied" {
  description = "Identifier of the reference-mode switch. Changes when the seed package changes."
  value       = terraform_data.reference_mode.id
}
