data "aws_iam_policy_document" "deny_direct_edits" {
  statement {
    sid    = "DenyDirectLambdaEdits"
    effect = "Deny"
    actions = [
      "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion", "lambda:DeleteFunction",
    ]
    resources = [var.function_arn, "${var.function_arn}:*"]
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
