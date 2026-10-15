variable "function_name" {
  description = "Name of the Lambda function the state machine invokes. Used to name resources."
  type        = string
}

variable "function_arn" {
  description = "ARN of the Lambda function the state machine invokes."
  type        = string
}

variable "partition" {
  description = "AWS partition, used to build service principal and ARNs."
  type        = string
}

variable "region" {
  description = "AWS region the state machine lives in."
  type        = string
}

variable "state_machine_type" {
  description = "STANDARD or EXPRESS. Express suits high-volume short workflows; Standard suits long-running or auditable ones."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "EXPRESS"], var.state_machine_type)
    error_message = "state_machine_type must be \"STANDARD\" or \"EXPRESS\"."
  }
}

variable "definition" {
  description = <<-EOT
    Amazon States Language definition as JSON. Leave null to use the built-in
    single-task definition that invokes the function with lambda:invoke and
    returns its output. Set this to own the workflow. The invoke permission on
    the role covers only var.function_arn, so a custom definition that calls
    other functions needs its own grants via additional_policy_json.
  EOT
  type        = string
  default     = null
}

variable "additional_policy_json" {
  description = "Optional extra IAM policy JSON attached to the state machine role (for example to call other services from the workflow)."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Retention for the state machine log group."
  type        = number
  default     = 30
}

variable "log_level" {
  description = "Execution logging level: ALL, ERROR, FATAL, or OFF."
  type        = string
  default     = "ERROR"

  validation {
    condition     = contains(["ALL", "ERROR", "FATAL", "OFF"], var.log_level)
    error_message = "log_level must be one of ALL, ERROR, FATAL, OFF."
  }
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
