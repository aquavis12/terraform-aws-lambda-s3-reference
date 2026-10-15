locals {
  # Default workflow: a single task that invokes the function and returns its
  # output. Uses the lambda:invoke optimized integration and retries the
  # transient Lambda service errors AWS recommends.
  default_definition = jsonencode({
    Comment = "Invoke ${var.function_name}"
    StartAt = "Invoke"
    States = {
      Invoke = {
        Type     = "Task"
        Resource = "arn:${var.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.function_arn
          "Payload.$"  = "$"
        }
        OutputPath = "$.Payload"
        Retry = [{
          ErrorEquals = [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException",
            "Lambda.TooManyRequestsException",
          ]
          IntervalSeconds = 2
          MaxAttempts     = 3
          BackoffRate     = 2
        }]
        End = true
      }
    }
  })

  definition = coalesce(var.definition, local.default_definition)
}

# ============================================================ logging
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/states/${var.function_name}-workflow"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ============================================================ role
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-sfn"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# Invoke grant, scoped to this one function.
data "aws_iam_policy_document" "invoke" {
  statement {
    sid       = "InvokeTargetFunction"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [var.function_arn, "${var.function_arn}:*"]
  }
}

resource "aws_iam_role_policy" "invoke" {
  name   = "invoke-lambda"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.invoke.json
}

resource "aws_iam_role_policy" "additional" {
  count  = var.additional_policy_json == null ? 0 : 1
  name   = "additional"
  role   = aws_iam_role.this.id
  policy = var.additional_policy_json
}

# CloudWatch Logs permissions that Step Functions needs to deliver logs. These
# log actions do not support resource scoping, which is expected here.
data "aws_iam_policy_document" "logs" {
  statement {
    sid    = "DeliverLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "logs" {
  name   = "state-machine-logs"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.logs.json
}

# ============================================================ state machine
resource "aws_sfn_state_machine" "this" {
  name       = "${var.function_name}-workflow"
  type       = var.state_machine_type
  role_arn   = aws_iam_role.this.arn
  definition = local.definition
  tags       = var.tags

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.this.arn}:*"
    include_execution_data = false
    level                  = var.log_level
  }

  depends_on = [
    aws_iam_role_policy.invoke,
    aws_iam_role_policy.logs,
  ]
}
