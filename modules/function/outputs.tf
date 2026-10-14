output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function."
  value       = aws_lambda_function.this.arn
}

output "execution_role_arn" {
  description = "Execution role ARN of the function."
  value       = aws_iam_role.exec.arn
}

output "reference_mode_id" {
  description = "Identifier of the reference-mode switch. Changes when the seed package changes."
  value       = terraform_data.reference_mode.id
}
