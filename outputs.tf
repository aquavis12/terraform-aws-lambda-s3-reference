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

output "api_endpoint" {
  description = "Base invoke URL of the HTTP API, or null when API Gateway wiring is disabled."
  value       = var.enable_api_gateway ? module.api_gateway[0].api_endpoint : null
}

output "api_id" {
  description = "ID of the HTTP API, or null when API Gateway wiring is disabled."
  value       = var.enable_api_gateway ? module.api_gateway[0].api_id : null
}

output "state_machine_arn" {
  description = "ARN of the state machine, or null when Step Functions wiring is disabled."
  value       = var.enable_step_functions ? module.step_functions[0].state_machine_arn : null
}
