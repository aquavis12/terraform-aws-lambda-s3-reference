output "policy_arn" {
  description = "ARN of the deny policy."
  value       = aws_iam_policy.deny_direct_edits.arn
}
