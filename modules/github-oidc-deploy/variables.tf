variable "function_name" {
  description = "Name of the Lambda function the deploy role targets."
  type        = string
}

variable "function_arn" {
  description = "ARN of the Lambda function the deploy role may update."
  type        = string
}

variable "artifact_bucket_arn" {
  description = "ARN of the artifact bucket the deploy role may write to."
  type        = string
}

variable "github_subjects" {
  description = "Fully-qualified OIDC subject claims allowed to assume the role."
  type        = list(string)
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Leave false if the account already has one."
  type        = bool
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
