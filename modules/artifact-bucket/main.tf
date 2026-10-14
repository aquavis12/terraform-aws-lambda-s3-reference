resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versioning is mandatory. Lambda identifies a build by its object version.
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.noncurrent_version_expiry_days == null ? 0 : 1
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiry_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# First package. Requires versioning so that version_id is populated.
resource "aws_s3_object" "seed" {
  bucket = aws_s3_bucket.this.id
  key    = var.seed_key
  source = var.seed_zip_path
  etag   = filemd5(var.seed_zip_path)
  tags   = var.tags

  depends_on = [aws_s3_bucket_versioning.this]
}

data "aws_iam_policy_document" "this" {
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

    resources = ["${aws_s3_bucket.this.arn}/${var.artifact_prefix}*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [var.function_arn]
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
        aws_s3_bucket.this.arn,
        "${aws_s3_bucket.this.arn}/*",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.this.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}
