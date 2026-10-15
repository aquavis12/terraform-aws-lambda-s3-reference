data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  partition   = data.aws_partition.current.partition
  bucket_name = coalesce(var.artifact_bucket_name, "${var.function_name}-artifacts-${local.account_id}-${local.region}")

  # Built from names rather than taken from the function resource, so the
  # bucket policy and roles can be created without a dependency cycle.
  function_arn = "arn:${local.partition}:lambda:${local.region}:${local.account_id}:function:${var.function_name}"

  seed_key        = "${var.artifact_prefix}${var.function_name}/bootstrap.zip"
  github_subjects = [for s in var.github_subjects : "repo:${var.github_repository}:${s}"]
}

module "artifact_bucket" {
  source = "./modules/artifact-bucket"

  bucket_name                    = local.bucket_name
  function_arn                   = local.function_arn
  artifact_prefix                = var.artifact_prefix
  seed_key                       = local.seed_key
  seed_zip_path                  = var.seed_zip_path
  deny_artifact_deletion         = var.deny_artifact_deletion
  noncurrent_version_expiry_days = var.noncurrent_version_expiry_days
  tags                           = var.tags
}

module "function" {
  source = "./modules/function"

  function_name         = var.function_name
  partition             = local.partition
  region                = local.region
  runtime               = var.runtime
  handler               = var.handler
  architectures         = var.architectures
  memory_size           = var.memory_size
  timeout               = var.timeout
  ephemeral_storage_mb  = var.ephemeral_storage_mb
  layers                = var.layers
  environment_variables = var.environment_variables
  log_retention_days    = var.log_retention_days
  execution_policy_json = var.execution_policy_json
  allowed_invokers      = var.allowed_invokers

  artifact_bucket_id       = module.artifact_bucket.bucket_id
  seed_key                 = module.artifact_bucket.seed_key
  seed_version_id          = module.artifact_bucket.seed_version_id
  bucket_policy_dependency = module.artifact_bucket.bucket_policy_id

  tags = var.tags
}

module "github_oidc_deploy" {
  source = "./modules/github-oidc-deploy"

  function_name        = var.function_name
  function_arn         = local.function_arn
  artifact_bucket_arn  = module.artifact_bucket.bucket_arn
  github_subjects      = local.github_subjects
  create_oidc_provider = var.create_oidc_provider
  tags                 = var.tags
}

module "human_deny" {
  source = "./modules/human-deny"

  function_name    = var.function_name
  function_arn     = local.function_arn
  human_role_names = var.human_role_names
  tags             = var.tags
}

# ------------------------------------------------------------- optional wiring
module "api_gateway" {
  source = "./modules/api-gateway"
  count  = var.enable_api_gateway ? 1 : 0

  function_name          = var.function_name
  function_arn           = module.function.function_arn
  function_invoke_arn    = module.function.function_invoke_arn
  routes                 = var.api_gateway.routes
  stage_name             = var.api_gateway.stage_name
  payload_format_version = var.api_gateway.payload_format_version
  cors_configuration     = var.api_gateway.cors_configuration
  log_retention_days     = var.api_gateway.log_retention_days
  tags                   = var.tags
}

module "step_functions" {
  source = "./modules/step-functions"
  count  = var.enable_step_functions ? 1 : 0

  function_name          = var.function_name
  function_arn           = module.function.function_arn
  partition              = local.partition
  region                 = local.region
  state_machine_type     = var.step_functions.state_machine_type
  definition             = var.step_functions.definition
  additional_policy_json = var.step_functions.additional_policy_json
  log_level              = var.step_functions.log_level
  log_retention_days     = var.step_functions.log_retention_days
  tags                   = var.tags
}
