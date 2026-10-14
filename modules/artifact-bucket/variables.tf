variable "bucket_name" {
  description = "Name of the artifact bucket."
  type        = string
}

variable "function_arn" {
  description = "ARN of the Lambda function the bucket serves. Scopes the Lambda read grant."
  type        = string
}

variable "artifact_prefix" {
  description = "Key prefix that holds deployment packages. The Lambda read grant covers this prefix only."
  type        = string
}

variable "seed_key" {
  description = "Object key for the seed deployment package."
  type        = string
}

variable "seed_zip_path" {
  description = "Local path to the seed deployment package to upload."
  type        = string
}

variable "deny_artifact_deletion" {
  description = "Deny object deletion and versioning changes for every principal."
  type        = bool
}

variable "noncurrent_version_expiry_days" {
  description = "Expire old object versions after this many days. Null disables expiry."
  type        = number
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
