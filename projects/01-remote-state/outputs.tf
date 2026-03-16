# =============================================================================
# outputs.tf — Project 01: Remote State
# =============================================================================

output "ssm_parameter_name" {
  description = "Name of the SSM parameter created as our Hello World resource"
  value       = aws_ssm_parameter.hello.name
}

output "ssm_parameter_arn" {
  description = "ARN of the SSM parameter"
  value       = aws_ssm_parameter.hello.arn
}
