output "deploy_role_arn" {
  description = "ARN of the role GitHub Actions assumes to deploy."
  value       = aws_iam_role.deploy.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in use."
  value       = local.oidc_provider_arn
}
