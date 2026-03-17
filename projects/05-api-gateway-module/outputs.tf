# =============================================================================
# outputs.tf — Project 2.3: API Gateway Module
# =============================================================================

output "invoke_url" {
  description = "Base URL of the HTTP API. Append a route path to call it: <invoke_url>/hello"
  value       = module.api_gateway.invoke_url
}

output "hello_endpoint" {
  description = "Ready-to-curl GET /hello endpoint"
  value       = "${module.api_gateway.invoke_url}/hello"
}

output "items_endpoint" {
  description = "Ready-to-curl GET /items endpoint"
  value       = "${module.api_gateway.invoke_url}/items"
}

output "api_id" {
  description = "API Gateway ID"
  value       = module.api_gateway.api_id
}

output "lambda_function_name" {
  description = "Name of the backing Lambda function"
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch Log Group for the Lambda function"
  value       = module.lambda.log_group_name
}

output "api_log_group" {
  description = "CloudWatch Log Group for API Gateway access logs"
  value       = module.api_gateway.log_group_name
}
