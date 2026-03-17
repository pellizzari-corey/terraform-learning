# =============================================================================
# modules/lambda/outputs.tf
# =============================================================================

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN used by API Gateway to invoke this function (differs from function_arn)"
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "ARN with the function version qualifier (e.g. arn:...:function:name:$LATEST)"
  value       = aws_lambda_function.this.qualified_arn
}

output "role_arn" {
  description = "ARN of the IAM execution role attached to the function"
  value       = aws_iam_role.lambda.arn
}

output "role_name" {
  description = "Name of the IAM execution role (useful for attaching additional policies)"
  value       = aws_iam_role.lambda.name
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for this function"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda.arn
}
