# ---------------------------------------------------------------- function
variable "function_name" {
  description = "Name of the Lambda function. Also used to name the bucket, roles and log group."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.function_name))
    error_message = "function_name must be 1-64 characters and contain only letters, numbers, hyphens and underscores."
  }
}

variable "runtime" {
  description = "Lambda runtime. Must match the Python version the package was built for."
  type        = string
  default     = "python3.12"
}

variable "handler" {
  description = "Handler in module.function form, for example main.handler."
  type        = string
  default     = "main.handler"
}

variable "architectures" {
  description = "Instruction set. The package must be built for the same one."
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "architectures must be exactly one of [\"x86_64\"] or [\"arm64\"]."
  }
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
  default     = 512

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "timeout" {
  description = "Timeout in seconds (maximum 900)."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "ephemeral_storage_mb" {
  description = "Size of /tmp in MB (512 to 10240)."
  type        = number
  default     = 512

  validation {
    condition     = var.ephemeral_storage_mb >= 512 && var.ephemeral_storage_mb <= 10240
    error_message = "ephemeral_storage_mb must be between 512 and 10240 MB."
  }
}

variable "layers" {
  description = <<-EOT
    ARNs of existing layer versions to attach. This module does not create
    layers. Layers are optional with self-managed S3 storage; you can bundle
    dependencies in the function zip instead. Keep large or shared compiled
    binaries in layers when it suits your build.
  EOT
  type        = list(string)
  default     = []
}

variable "environment_variables" {
  description = "Environment variables for the function."
  type        = map(string)
  default     = {}
}

variable "allowed_invokers" {
  description = <<-EOT
    Extra resource-based permissions that let other services invoke the
    function, keyed by statement id. The built-in API Gateway and Step
    Functions wiring (enable_api_gateway, enable_step_functions) add their own
    permissions automatically; use this for anything you wire by hand.
  EOT
  type = map(object({
    principal      = string
    source_arn     = optional(string)
    source_account = optional(string)
  }))
  default = {}
}

# ------------------------------------------------------------- seed package
variable "seed_zip_path" {
  description = <<-EOT
    Local path to the first deployment package. Terraform uploads it to the
    artifact bucket and creates the function from it. After that, the CI/CD
    pipeline owns the code and Terraform ignores code changes.
  EOT
  type        = string
}

# ------------------------------------------------------------- artifact bucket
variable "artifact_bucket_name" {
  description = "Name of the artifact bucket. Defaults to <function_name>-artifacts-<account>-<region>."
  type        = string
  default     = null
}

variable "artifact_prefix" {
  description = "Key prefix in the bucket that holds deployment packages. The Lambda read grant covers this prefix only."
  type        = string
  default     = "functions/"
}

variable "deny_artifact_deletion" {
  description = <<-EOT
    Deny object deletion and versioning changes for every principal, including
    administrators. Recommended: a live function re-reads its object, so a
    deleted object makes the function Inactive. Note that with this on,
    `terraform destroy` cannot empty the bucket; see the README.
  EOT
  type        = bool
  default     = true
}

variable "noncurrent_version_expiry_days" {
  description = <<-EOT
    Expire old object versions after this many days. Null disables expiry.
    Leave null unless you have checked that no published version still
    references the versions you would expire.
  EOT
  type        = number
  default     = null
}

# ------------------------------------------------------------- logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

# ------------------------------------------------------------- execution role
variable "execution_policy_json" {
  description = "Optional inline policy JSON for the execution role (for example DynamoDB, S3 and Textract access)."
  type        = string
  default     = null
}

# ------------------------------------------------------------- CI/CD
variable "github_repository" {
  description = "GitHub repository allowed to deploy, in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must be in owner/name form, for example my-org/my-repo."
  }
}

variable "github_subjects" {
  description = <<-EOT
    Subjects allowed to assume the deploy role, relative to the repository.
    Use "environment:<name>" when the workflow job declares a GitHub
    Environment, or "ref:refs/heads/<branch>" otherwise. Keep this narrow.
  EOT
  type        = list(string)
  default     = ["environment:main"]
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Leave false if the account already has one, because only one is allowed per URL."
  type        = bool
  default     = false
}

# ------------------------------------------------------------- human access
variable "human_role_names" {
  description = "IAM role names that must not edit this function directly. The deny policy is attached to each."
  type        = list(string)
  default     = []
}

# ------------------------------------------------------------- API Gateway wiring
variable "enable_api_gateway" {
  description = "Front the function with an HTTP API (API Gateway v2) using an AWS_PROXY integration."
  type        = bool
  default     = false
}

variable "api_gateway" {
  description = <<-EOT
    Settings for the HTTP API, used only when enable_api_gateway is true.
    routes default to a catch-all so the function owns routing. cors_configuration
    is null (disabled) by default. See modules/api-gateway for the full shape.
  EOT
  type = object({
    routes = optional(map(object({
      route_key = string
    })), { default = { route_key = "ANY /{proxy+}" } })
    stage_name             = optional(string, "$default")
    payload_format_version = optional(string, "2.0")
    cors_configuration = optional(object({
      allow_origins     = optional(list(string), [])
      allow_methods     = optional(list(string), [])
      allow_headers     = optional(list(string), [])
      expose_headers    = optional(list(string), [])
      allow_credentials = optional(bool, false)
      max_age           = optional(number)
    }))
    log_retention_days = optional(number, 30)
  })
  default = {}
}

# ------------------------------------------------------------- Step Functions wiring
variable "enable_step_functions" {
  description = "Create a Step Functions state machine that invokes the function."
  type        = bool
  default     = false
}

variable "step_functions" {
  description = <<-EOT
    Settings for the state machine, used only when enable_step_functions is
    true. definition null uses the built-in single-task invoke workflow. See
    modules/step-functions for the full shape.
  EOT
  type = object({
    state_machine_type     = optional(string, "STANDARD")
    definition             = optional(string)
    additional_policy_json = optional(string)
    log_level              = optional(string, "ERROR")
    log_retention_days     = optional(number, 30)
  })
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
  default     = {}
}
