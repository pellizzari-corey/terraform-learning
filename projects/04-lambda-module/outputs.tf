# =============================================================================
# outputs.tf — Project 2.2: Lambda Module
# =============================================================================

# --- Public Lambda ---
output "lambda_public_name" {
  description = "Name of the public (non-VPC) Lambda function"
  value       = module.lambda_public.function_name
}

output "lambda_public_arn" {
  description = "ARN of the public Lambda function"
  value       = module.lambda_public.function_arn
}

output "lambda_public_log_group" {
  description = "CloudWatch Log Group for the public Lambda"
  value       = module.lambda_public.log_group_name
}

# --- VPC Lambda ---
output "lambda_vpc_name" {
  description = "Name of the VPC-attached Lambda function"
  value       = module.lambda_vpc.function_name
}

output "lambda_vpc_arn" {
  description = "ARN of the VPC Lambda function"
  value       = module.lambda_vpc.function_arn
}

output "lambda_vpc_log_group" {
  description = "CloudWatch Log Group for the VPC Lambda"
  value       = module.lambda_vpc.log_group_name
}

# --- VPC (from nested vpc module call) ---
output "vpc_id" {
  description = "ID of the VPC the Lambda is attached to"
  value       = module.vpc.vpc_id
}
