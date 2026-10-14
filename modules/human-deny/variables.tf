variable "function_name" {
  description = "Name of the Lambda function the deny policy protects."
  type        = string
}

variable "function_arn" {
  description = "ARN of the Lambda function the deny policy protects."
  type        = string
}

variable "human_role_names" {
  description = "IAM role names that must not edit this function directly."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
