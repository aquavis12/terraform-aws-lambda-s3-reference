data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
  partition   = data.aws_partition.current.partition
  bucket_name = coalesce(var.artifact_bucket_name, "${var.function_name}-artifacts-${local.account_id}-${local.region}")

  # Built from names rather than taken from the function resource, so the
  # bucket policy can be created before the function without a cycle.
  function_arn = "arn:${local.partition}:lambda:${local.region}:${local.account_id}:function:${var.function_name}"
  role_arn     = "arn:${local.partition}:iam::${local.account_id}:role/${var.function_name}-exec"

  seed_key = "${var.artifact_prefix}${var.function_name}/bootstrap.zip"

  github_subjects = [for s in var.github_subjects : "repo:${var.github_repository}:${s}"]
}

# ============================================================ artifact bucket
resource "aws_s3_bucket" "artifacts" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning is mandatory. Lambda identifies a build by its object version.
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count  = var.noncurrent_version_expiry_days == null ? 0 : 1
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiry_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.artifacts]
}

# First package. Requires versioning so that version_id is populated.
resource "aws_s3_object" "seed" {
  bucket = aws_s3_bucket.artifacts.id
  key    = local.seed_key
  source = var.seed_zip_path
  etag   = filemd5(var.seed_zip_path)
  tags   = var.tags

  depends_on = [aws_s3_bucket_versioning.artifacts]
}

data "aws_iam_policy_document" "artifacts" {
  # The Lambda service reads the package. This is the service principal, not
  # the execution role. The SourceArn condition limits the grant to this function.
  statement {
    sid     = "LambdaSelfManagedCodeAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:GetObjectVersion"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.artifacts.arn}/${var.artifact_prefix}*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.function_arn]
    }
  }

  dynamic "statement" {
    for_each = var.deny_artifact_deletion ? [1] : []

    content {
      sid     = "DenyArtifactDeletion"
      effect  = "Deny"
      actions = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:PutBucketVersioning"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      resources = [
        aws_s3_bucket.artifacts.arn,
        "${aws_s3_bucket.artifacts.arn}/*",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  policy = data.aws_iam_policy_document.artifacts.json

  depends_on = [aws_s3_bucket_public_access_block.artifacts]
}

# ============================================================ logging
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ============================================================ execution role
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.function_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_logging" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "app" {
  count  = var.execution_policy_json == null ? 0 : 1
  name   = "app-permissions"
  role   = aws_iam_role.exec.id
  policy = var.execution_policy_json
}

# ============================================================ function
# Created from the seed package. Code attributes are ignored afterwards, so
# Terraform never calls UpdateFunctionCode on a later apply. Reference mode is
# set by the terraform_data below, because the AWS provider does not yet
# expose s3_object_storage_mode.
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.exec.arn
  runtime       = var.runtime
  handler       = var.handler
  architectures = var.architectures
  memory_size   = var.memory_size
  timeout       = var.timeout
  layers        = var.layers

  ephemeral_storage {
    size = var.ephemeral_storage_mb
  }

  s3_bucket         = aws_s3_bucket.artifacts.id
  s3_key            = aws_s3_object.seed.key
  s3_object_version = aws_s3_object.seed.version_id

  environment {
    variables = var.environment_variables
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy_attachment.basic_logging,
    aws_iam_role_policy.app,
  ]

  lifecycle {
    ignore_changes = [s3_bucket, s3_key, s3_object_version, source_code_hash]
  }
}

# Switches the function to reference mode. Runs on create and whenever the
# seed package changes. Requires AWS CLI 2.35.12 or later on the machine
# running Terraform, and lambda:UpdateFunctionCode for the applier.
resource "terraform_data" "reference_mode" {
  triggers_replace = [aws_s3_object.seed.version_id]

  depends_on = [
    aws_s3_bucket_policy.artifacts,
    aws_lambda_function.this,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      aws lambda update-function-code \
        --function-name "${var.function_name}" \
        --region "${local.region}" \
        --s3-bucket "${aws_s3_bucket.artifacts.id}" \
        --s3-key "${aws_s3_object.seed.key}" \
        --s3-object-version "${aws_s3_object.seed.version_id}" \
        --s3-object-storage-mode REFERENCE \
        --no-cli-pager
      aws lambda wait function-updated-v2 \
        --function-name "${var.function_name}" --region "${local.region}"
      mode="$(aws lambda get-function --function-name "${var.function_name}" \
        --region "${local.region}" \
        --query 'Code.SourceKMSKeyArn && Code.S3ObjectStorageMode || Code.S3ObjectStorageMode' \
        --output text 2>/dev/null || true)"
      if [ "$mode" != "REFERENCE" ]; then
        # Fallback for CLI versions that nest the field differently.
        mode="$(aws lambda get-function --function-name "${var.function_name}" \
          --region "${local.region}" --query Code --output json \
          | grep -o 'REFERENCE' | head -n1 || true)"
      fi
      [ "$mode" = "REFERENCE" ] || { echo "function is not in REFERENCE mode"; exit 1; }
    EOT
  }
}

# ============================================================ GitHub OIDC
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
  tags = var.tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.github_subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.function_name}-github-deploy"
  description        = "Assumed by GitHub Actions to deploy ${var.function_name}"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
  tags               = var.tags
}

# No iam:PassRole and no lambda:UpdateFunctionConfiguration. The pipeline
# changes code only.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "PutArtifacts"
    actions = [
      "s3:PutObject", "s3:GetObject", "s3:GetObjectVersion",
      "s3:ListBucket", "s3:ListBucketVersions",
    ]
    resources = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
  }

  statement {
    sid = "DeployFunction"
    actions = [
      "lambda:GetFunction", "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode", "lambda:PublishVersion",
      "lambda:ListVersionsByFunction", "lambda:InvokeFunction",
    ]
    resources = [local.function_arn, "${local.function_arn}:*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# ============================================================ human deny
data "aws_iam_policy_document" "deny_direct_edits" {
  statement {
    sid    = "DenyDirectLambdaEdits"
    effect = "Deny"
    actions = [
      "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion", "lambda:DeleteFunction",
    ]
    resources = [local.function_arn, "${local.function_arn}:*"]
  }
}

resource "aws_iam_policy" "deny_direct_edits" {
  name        = "${var.function_name}-deny-direct-edits"
  description = "Blocks console and CLI edits to ${var.function_name}. The pipeline role is not covered."
  policy      = data.aws_iam_policy_document.deny_direct_edits.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "deny_direct_edits" {
  for_each   = toset(var.human_role_names)
  role       = each.value
  policy_arn = aws_iam_policy.deny_direct_edits.arn
}
