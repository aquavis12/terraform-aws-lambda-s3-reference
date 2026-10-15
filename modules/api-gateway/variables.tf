variable "function_name" {
  description = "Name of the Lambda function this API fronts. Used to name API resources."
  type        = string
}

variable "function_arn" {
  description = "ARN of the Lambda function to integrate with (AWS_PROXY)."
  type        = string
}

variable "function_invoke_arn" {
  description = <<-EOT
    Invoke ARN of the Lambda function (aws_lambda_function.invoke_arn). This is
    the arn:aws:apigateway:...:lambda:path/... form the integration requires,
    not the plain function ARN.
  EOT
  type        = string
}

variable "routes" {
  description = <<-EOT
    Routes to expose, each sending to the Lambda via AWS_PROXY. Keyed by an
    arbitrary id. Use the HTTP API route key form, for example "GET /items" or
    "ANY /{proxy+}". Default exposes a catch-all so the function owns routing.
  EOT
  type = map(object({
    route_key = string
  }))
  default = {
    default = { route_key = "ANY /{proxy+}" }
  }
}

variable "stage_name" {
  description = "Name of the deployed stage. $default removes the stage name from the invoke URL."
  type        = string
  default     = "$default"
}

variable "payload_format_version" {
  description = "Lambda proxy payload format. 2.0 is current for HTTP APIs."
  type        = string
  default     = "2.0"

  validation {
    condition     = contains(["1.0", "2.0"], var.payload_format_version)
    error_message = "payload_format_version must be \"1.0\" or \"2.0\"."
  }
}

variable "cors_configuration" {
  description = <<-EOT
    Optional CORS settings for the HTTP API. Null disables CORS. When set,
    provide the allowed origins/methods/headers your browser clients need.
  EOT
  type = object({
    allow_origins     = optional(list(string), [])
    allow_methods     = optional(list(string), [])
    allow_headers     = optional(list(string), [])
    expose_headers    = optional(list(string), [])
    allow_credentials = optional(bool, false)
    max_age           = optional(number)
  })
  default = null
}

variable "log_retention_days" {
  description = "Retention for the API access log group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to all resources that support them."
  type        = map(string)
}
