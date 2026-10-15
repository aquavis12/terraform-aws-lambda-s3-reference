# AWS Lambda S3 Reference-Mode Terraform module

Terraform module which creates a Lambda function that runs in **reference
mode**: the function reads its deployment package directly from an S3 bucket you
own, and GitHub Actions deploys new code through an OIDC-trusted role. The
module also provisions the artifact bucket, the IAM roles, the GitHub OIDC
trust, and an optional deny policy that blocks direct console or CLI edits.

Terraform owns the infrastructure and configuration. The pipeline owns the code.

## Usage

### From the Terraform Registry

```hcl
module "lambda_function" {
  source  = "aquavis12/lambda-s3-reference/aws"
  version = "~> 1.2"

  function_name     = "my-function"
  handler           = "main.handler"
  seed_zip_path     = "${path.module}/seed/bootstrap.zip"
  github_repository = "aquavis12/my-repo"
  github_subjects   = ["environment:main"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

### From Git, pinned to a release tag

```hcl
module "lambda_function" {
  source = "git::https://github.com/aquavis12/terraform-aws-lambda-s3-reference.git?ref=v1.2.1"

  function_name     = "my-function"
  handler           = "main.handler"
  seed_zip_path     = "${path.module}/seed/bootstrap.zip"
  github_repository = "aquavis12/my-repo"
  github_subjects   = ["environment:main"]
}
```

`seed_zip_path` must point at a real zip built for your runtime and
architecture. After the first apply, the pipeline owns the code and Terraform
ignores code changes. Set the module outputs `artifact_bucket` and
`deploy_role_arn` as `ARTIFACT_BUCKET` and `AWS_DEPLOY_ROLE_ARN` in the GitHub
Environment, and set `FUNCTION_NAME` to `function_name`.

### With API Gateway and Step Functions wiring

Both are optional and off by default. Enabling them does not change the
reference-mode contract: they add only invoke permissions and caller resources,
never the function's code.

```hcl
module "lambda_function" {
  source  = "aquavis12/lambda-s3-reference/aws"
  version = "~> 1.0"

  function_name     = "my-function"
  handler           = "main.handler"
  seed_zip_path     = "${path.module}/seed/bootstrap.zip"
  github_repository = "aquavis12/my-repo"

  # Front the function with an HTTP API (API Gateway v2, AWS_PROXY).
  enable_api_gateway = true
  api_gateway = {
    routes = {
      items  = { route_key = "GET /items" }
      create = { route_key = "POST /items" }
    }
    cors_configuration = {
      allow_origins = ["https://app.example.com"]
      allow_methods = ["GET", "POST"]
    }
  }

  # Create a state machine that invokes the function.
  enable_step_functions = true
  step_functions = {
    state_machine_type = "STANDARD"
    # definition = file("${path.module}/workflow.asl.json") # or use the built-in single-task default
  }
}
```

The HTTP API invoke URL is exposed as the `api_endpoint` output, and the state
machine as `state_machine_arn`. For any other caller (S3 notifications,
EventBridge, SNS), grant invoke rights with the `allowed_invokers` input instead
of wiring an `aws_lambda_permission` by hand.

## What it creates

| Resource | Purpose |
|---|---|
| S3 bucket | Artifact store. Versioned, encrypted with SSE-S3, public access blocked |
| Bucket policy | Lets the Lambda service read the artifact prefix, scoped to this function. Optionally denies deletes for everyone |
| Seed object | The first package, uploaded from `seed_zip_path` |
| Lambda function | Created from the seed package, then switched to reference mode |
| Log group | Retention set by `log_retention_days` |
| Execution role | Basic logging, plus inline policies you supply (`execution_policy_json`, or `execution_policy_jsons` keyed per concern) and any `managed_policy_arns` you attach |
| Deploy role | Assumed by GitHub Actions through OIDC. Can update code and publish, nothing else |
| Deny policy | Optional. Blocks code and configuration edits by named human roles |
| HTTP API | Optional (`enable_api_gateway`). API Gateway v2 with an AWS_PROXY integration, access logging, and an invoke permission scoped to this API |
| State machine | Optional (`enable_step_functions`). Step Functions workflow with a dedicated role allowed to invoke only this function |

## Examples

- [basic](https://github.com/aquavis12/terraform-aws-lambda-s3-reference/tree/master/examples/basic) - Lambda in reference mode with an S3 artifact bucket, a GitHub OIDC deploy role, and a human deny policy

## Known limitations

**Reference mode is a local-exec step.** The AWS provider does not yet expose
`s3_object_storage_mode` on `aws_lambda_function`. The `terraform_data.reference_mode`
resource runs `scripts/set-reference-mode.sh` through `bash` instead, and
re-runs when the seed package changes. When the provider adds the argument,
replace that resource with the argument and remove the script.

**Code is ignored after creation.** `ignore_changes` covers the code attributes,
so Terraform never changes code on later applies. Deploy code through the
pipeline.

**Destroy needs a manual step when deletion is denied.** With
`deny_artifact_deletion = true`, no principal can delete objects or versions, so
`terraform destroy` cannot empty the bucket. To tear down: apply with
`deny_artifact_deletion = false` (or detach the deny), delete all object
versions and delete markers, then run `terraform destroy`. This is intentional
friction; do it under a change request.

**Noncurrent-version expiry is off by default.** `noncurrent_version_expiry_days`
is null. A lifecycle rule that expires old versions can break a published
version that still points at them. Turn it on only after checking the versions
in use.

**The deny policy also blocks configuration edits.** Once a human-deny policy is
attached, `UpdateFunctionConfiguration` is blocked for those roles too. Changes
to memory, timeout, or layers need the policy detached first.

**API Gateway cannot redeploy on code changes from Terraform.** The HTTP API
stage uses `auto_deploy`, so route and integration changes ship automatically.
But code changes are invisible to Terraform by design (reference mode), so a new
function build does not trigger an API redeploy from here. If you need that,
drive it from the pipeline after the upload.

## Requirements

- Terraform 1.5 or later, with AWS provider 6.0 or later.
- `bash` and AWS CLI 2.35.12 or later on the machine that runs
  `terraform apply`. The reference-mode switch runs
  `scripts/set-reference-mode.sh` through `bash`, because the AWS provider does
  not yet expose the storage mode. On Windows, use Git Bash or WSL. CI runners
  on Linux or macOS already have `bash`.
- The applier needs `lambda:UpdateFunctionCode`, `lambda:GetFunction`,
  `lambda:GetFunctionConfiguration`, and `s3:PutObject` on the bucket.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.69.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_api_gateway"></a> [api\_gateway](#module\_api\_gateway) | ./modules/api-gateway | n/a |
| <a name="module_artifact_bucket"></a> [artifact\_bucket](#module\_artifact\_bucket) | ./modules/artifact-bucket | n/a |
| <a name="module_function"></a> [function](#module\_function) | ./modules/function | n/a |
| <a name="module_github_oidc_deploy"></a> [github\_oidc\_deploy](#module\_github\_oidc\_deploy) | ./modules/github-oidc-deploy | n/a |
| <a name="module_human_deny"></a> [human\_deny](#module\_human\_deny) | ./modules/human-deny | n/a |
| <a name="module_step_functions"></a> [step\_functions](#module\_step\_functions) | ./modules/step-functions | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_invokers"></a> [allowed\_invokers](#input\_allowed\_invokers) | Extra resource-based permissions that let other services invoke the<br/>function, keyed by statement id. The built-in API Gateway and Step<br/>Functions wiring (enable\_api\_gateway, enable\_step\_functions) add their own<br/>permissions automatically; use this for anything you wire by hand. | <pre>map(object({<br/>    principal      = string<br/>    source_arn     = optional(string)<br/>    source_account = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_api_gateway"></a> [api\_gateway](#input\_api\_gateway) | Settings for the HTTP API, used only when enable\_api\_gateway is true.<br/>routes default to a catch-all so the function owns routing. cors\_configuration<br/>is null (disabled) by default. See modules/api-gateway for the full shape. | <pre>object({<br/>    routes = optional(map(object({<br/>      route_key = string<br/>    })), { default = { route_key = "ANY /{proxy+}" } })<br/>    stage_name             = optional(string, "$default")<br/>    payload_format_version = optional(string, "2.0")<br/>    cors_configuration = optional(object({<br/>      allow_origins     = optional(list(string), [])<br/>      allow_methods     = optional(list(string), [])<br/>      allow_headers     = optional(list(string), [])<br/>      expose_headers    = optional(list(string), [])<br/>      allow_credentials = optional(bool, false)<br/>      max_age           = optional(number)<br/>    }))<br/>    log_retention_days = optional(number, 30)<br/>  })</pre> | `{}` | no |
| <a name="input_architectures"></a> [architectures](#input\_architectures) | Instruction set. The package must be built for the same one. | `list(string)` | <pre>[<br/>  "x86_64"<br/>]</pre> | no |
| <a name="input_artifact_bucket_name"></a> [artifact\_bucket\_name](#input\_artifact\_bucket\_name) | Name of the artifact bucket. Defaults to <function\_name>-artifacts-<account>-<region>. | `string` | `null` | no |
| <a name="input_artifact_prefix"></a> [artifact\_prefix](#input\_artifact\_prefix) | Key prefix in the bucket that holds deployment packages. The Lambda read grant covers this prefix only. | `string` | `"functions/"` | no |
| <a name="input_create_oidc_provider"></a> [create\_oidc\_provider](#input\_create\_oidc\_provider) | Create the GitHub OIDC provider. Leave false if the account already has one, because only one is allowed per URL. | `bool` | `false` | no |
| <a name="input_deny_artifact_deletion"></a> [deny\_artifact\_deletion](#input\_deny\_artifact\_deletion) | Deny object deletion and versioning changes for every principal, including<br/>administrators. Recommended: a live function re-reads its object, so a<br/>deleted object makes the function Inactive. Note that with this on,<br/>`terraform destroy` cannot empty the bucket; see the README. | `bool` | `true` | no |
| <a name="input_enable_api_gateway"></a> [enable\_api\_gateway](#input\_enable\_api\_gateway) | Front the function with an HTTP API (API Gateway v2) using an AWS\_PROXY integration. | `bool` | `false` | no |
| <a name="input_enable_step_functions"></a> [enable\_step\_functions](#input\_enable\_step\_functions) | Create a Step Functions state machine that invokes the function. | `bool` | `false` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Environment variables for the function. | `map(string)` | `{}` | no |
| <a name="input_ephemeral_storage_mb"></a> [ephemeral\_storage\_mb](#input\_ephemeral\_storage\_mb) | Size of /tmp in MB (512 to 10240). | `number` | `512` | no |
| <a name="input_execution_policy_json"></a> [execution\_policy\_json](#input\_execution\_policy\_json) | Optional inline policy JSON for the execution role (for example DynamoDB, S3 and Textract access). | `string` | `null` | no |
| <a name="input_execution_policy_jsons"></a> [execution\_policy\_jsons](#input\_execution\_policy\_jsons) | Additional inline policies for the execution role, keyed by name. Prefer<br/>this over one big execution\_policy\_json when the function has several event<br/>sources: give each (for example "sqs", "dynamodb-streams") its own entry.<br/>Each value is an IAM policy JSON document. | `map(string)` | `{}` | no |
| <a name="input_function_name"></a> [function\_name](#input\_function\_name) | Name of the Lambda function. Also used to name the bucket, roles and log group. | `string` | n/a | yes |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository allowed to deploy, in owner/name form. | `string` | n/a | yes |
| <a name="input_github_subjects"></a> [github\_subjects](#input\_github\_subjects) | Subjects allowed to assume the deploy role, relative to the repository.<br/>Use "environment:<name>" when the workflow job declares a GitHub<br/>Environment, or "ref:refs/heads/<branch>" otherwise. Keep this narrow. | `list(string)` | <pre>[<br/>  "environment:main"<br/>]</pre> | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Handler in module.function form, for example main.handler. | `string` | `"main.handler"` | no |
| <a name="input_human_role_names"></a> [human\_role\_names](#input\_human\_role\_names) | IAM role names that must not edit this function directly. The deny policy is attached to each. | `list(string)` | `[]` | no |
| <a name="input_layers"></a> [layers](#input\_layers) | ARNs of existing layer versions to attach. This module does not create<br/>layers. Layers are optional with self-managed S3 storage; you can bundle<br/>dependencies in the function zip instead. Keep large or shared compiled<br/>binaries in layers when it suits your build. | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days. | `number` | `30` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | ARNs of existing managed policies to attach to the execution role. | `list(string)` | `[]` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory in MB. | `number` | `512` | no |
| <a name="input_noncurrent_version_expiry_days"></a> [noncurrent\_version\_expiry\_days](#input\_noncurrent\_version\_expiry\_days) | Expire old object versions after this many days. Null disables expiry.<br/>Leave null unless you have checked that no published version still<br/>references the versions you would expire. | `number` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda runtime. Must match the Python version the package was built for. | `string` | `"python3.12"` | no |
| <a name="input_seed_zip_path"></a> [seed\_zip\_path](#input\_seed\_zip\_path) | Local path to the first deployment package. Terraform uploads it to the<br/>artifact bucket and creates the function from it. After that, the CI/CD<br/>pipeline owns the code and Terraform ignores code changes. | `string` | n/a | yes |
| <a name="input_step_functions"></a> [step\_functions](#input\_step\_functions) | Settings for the state machine, used only when enable\_step\_functions is<br/>true. definition null uses the built-in single-task invoke workflow. See<br/>modules/step-functions for the full shape. | <pre>object({<br/>    state_machine_type     = optional(string, "STANDARD")<br/>    definition             = optional(string)<br/>    additional_policy_json = optional(string)<br/>    log_level              = optional(string, "ERROR")<br/>    log_retention_days     = optional(number, 30)<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources that support them. | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Timeout in seconds (maximum 900). | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_endpoint"></a> [api\_endpoint](#output\_api\_endpoint) | Base invoke URL of the HTTP API, or null when API Gateway wiring is disabled. |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | ID of the HTTP API, or null when API Gateway wiring is disabled. |
| <a name="output_artifact_bucket"></a> [artifact\_bucket](#output\_artifact\_bucket) | Artifact bucket name. Set this as ARTIFACT\_BUCKET in the pipeline. |
| <a name="output_deploy_role_arn"></a> [deploy\_role\_arn](#output\_deploy\_role\_arn) | Role for GitHub Actions. Set this as AWS\_DEPLOY\_ROLE\_ARN in the GitHub Environment. |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | Execution role of the function. |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | ARN of the Lambda function. |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Name of the Lambda function. |
| <a name="output_reference_mode_applied"></a> [reference\_mode\_applied](#output\_reference\_mode\_applied) | Identifier of the reference-mode switch. Changes when the seed package changes. |
| <a name="output_state_machine_arn"></a> [state\_machine\_arn](#output\_state\_machine\_arn) | ARN of the state machine, or null when Step Functions wiring is disabled. |
<!-- END_TF_DOCS -->

## Authors

Maintained by [vishnu](https://github.com/aquavis12).

## License

MIT Licensed. See [LICENSE](https://github.com/aquavis12/terraform-aws-lambda-s3-reference/blob/master/LICENSE).
