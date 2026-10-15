variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "partition" {
  description = "AWS partition, used to build the managed policy ARN."
  type        = string
}

variable "region" {
  description = "AWS region the function lives in."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
}

variable "handler" {
  description = "Handler in module.function form."
  type        = string
}

variable "architectures" {
  description = "Instruction set the package was built for."
  type        = list(string)
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
}

variable "timeout" {
  description = "Timeout in seconds."
  type        = number
}

variable "ephemeral_storage_mb" {
  description = "Size of /tmp in MB."
  type        = number
}

variable "layers" {
  description = "ARNs of existing layer versions to attach."
  type        = list(string)
}

variable "environment_variables" {
  description = "Environment variables for the function."
  type        = map(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}

variable "execution_policy_json" {
  description = "Optional inline policy JSON for the execution role."
  type        = string
}

variable "artifact_bucket_id" {
  description = "Name of the artifact bucket holding the package."
  type        = string
}

variable "seed_key" {
  description = "Object key of the seed package."
  type        = string
}

variable "seed_version_id" {
  description = "Version id of the seed package. Also triggers the reference-mode switch."
  type        = string
}

variable "bucket_policy_dependency" {
  description = "Opaque value used to order the function after the bucket policy exists."
  type        = string
}

variable "allowed_invokers" {
  description = <<-EOT
    Resource-based permissions that let other services invoke this function.
    Keyed by a stable statement id. This only touches the function's resource
    policy, never its code, so it is independent of reference mode.

    - principal:   service principal allowed to invoke, e.g. "apigateway.amazonaws.com".
    - source_arn:  optional ARN that scopes the grant to one caller. Strongly
                   recommended; without it any resource using that principal can invoke.
    - source_account: optional account id, useful when source_arn is not known at plan time.
  EOT
  type = map(object({
    principal      = string
    source_arn     = optional(string)
    source_account = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
