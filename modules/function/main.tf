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
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

  s3_bucket         = var.artifact_bucket_id
  s3_key            = var.seed_key
  s3_object_version = var.seed_version_id

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
# seed package changes. Requires bash and AWS CLI 2.35.12 or later on the
# machine running Terraform, and lambda:UpdateFunctionCode for the applier.
resource "terraform_data" "reference_mode" {
  # Include the bucket policy id so this re-runs if the policy changes, and so
  # it is ordered after the policy exists (the Lambda service needs read access
  # before the reference-mode switch).
  triggers_replace = [var.seed_version_id, var.bucket_policy_dependency]

  depends_on = [aws_lambda_function.this]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "'${path.module}/scripts/set-reference-mode.sh'"

    environment = {
      FUNCTION_NAME     = var.function_name
      AWS_REGION        = var.region
      S3_BUCKET         = var.artifact_bucket_id
      S3_KEY            = var.seed_key
      S3_OBJECT_VERSION = var.seed_version_id
    }
  }
}

# ============================================================ invoke permissions
# Resource-based policy statements that let other services call this function.
# These touch only the function's resource policy, not its code, so they are
# safe alongside reference mode.
resource "aws_lambda_permission" "invoke" {
  for_each = var.allowed_invokers

  statement_id   = each.key
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.this.function_name
  principal      = each.value.principal
  source_arn     = each.value.source_arn
  source_account = each.value.source_account
}
