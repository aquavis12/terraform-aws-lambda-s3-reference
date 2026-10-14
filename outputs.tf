output "function_name" {
  description = "Name of the Lambda function."
  value       = module.function.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = module.function.function_arn
}

output "artifact_bucket" {
  description = "Artifact bucket name. Set this as ARTIFACT_BUCKET in the pipeline."
  value       = module.artifact_bucket.bucket_id
}

output "execution_role_arn" {
  description = "Execution role of the function."
  value       = module.function.execution_role_arn
}

output "deploy_role_arn" {
  description = "Role for GitHub Actions. Set this as AWS_DEPLOY_ROLE_ARN in the GitHub Environment."
  value       = module.github_oidc_deploy.deploy_role_arn
}

output "reference_mode_applied" {
  description = "Identifier of the reference-mode switch. Changes when the seed package changes."
  value       = module.function.reference_mode_id
}
