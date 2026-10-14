# Basic example

Creates a Lambda function in reference mode, backed by an S3 artifact bucket,
with a GitHub OIDC deploy role and a human deny policy.

## Usage

```bash
# Build the seed package first, then:
terraform init
terraform plan
terraform apply
```

Before running, provide a seed package at `seed/bootstrap.zip` (built for the
runtime and architecture configured in the module call), and replace the
placeholder values in `main.tf`:

- `layers` — your own layer ARNs (or remove the argument)
- `execution_policy_json` — the least-privilege policy your function needs
- `github_repository` and `github_subjects` — your repo and allowed subjects
- `human_role_names` — the IAM roles that must not edit the function directly

Set `create_oidc_provider = true` only if the account has no GitHub OIDC
provider yet.

## Outputs

| Name | Description |
|---|---|
| `function_arn` | ARN of the Lambda function. |
| `artifact_bucket` | Artifact bucket name. Set as `ARTIFACT_BUCKET` in the pipeline. |
| `deploy_role_arn` | Role for GitHub Actions. Set as `AWS_DEPLOY_ROLE_ARN` in the GitHub Environment. |
