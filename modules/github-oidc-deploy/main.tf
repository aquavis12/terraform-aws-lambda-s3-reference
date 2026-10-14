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

data "aws_iam_policy_document" "trust" {
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
      values   = var.github_subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.function_name}-github-deploy"
  description        = "Assumed by GitHub Actions to deploy ${var.function_name}"
  assume_role_policy = data.aws_iam_policy_document.trust.json
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
    resources = [var.artifact_bucket_arn, "${var.artifact_bucket_arn}/*"]
  }

  statement {
    sid = "DeployFunction"
    actions = [
      "lambda:GetFunction", "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode", "lambda:PublishVersion",
      "lambda:ListVersionsByFunction", "lambda:InvokeFunction",
    ]
    resources = [var.function_arn, "${var.function_arn}:*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
