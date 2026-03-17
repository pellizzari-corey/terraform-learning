# =============================================================================
# modules/api_gateway/outputs.tf
# =============================================================================

output "api_id" {
  description = "ID of the HTTP API"
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of the HTTP API"
  value       = aws_apigatewayv2_api.this.arn
}

output "execution_arn" {
  description = "Execution ARN of the API — used to scope Lambda permissions"
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "invoke_url" {
  description = "Base URL to invoke the API (e.g. https://abc123.execute-api.us-east-1.amazonaws.com)"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "stage_id" {
  description = "ID of the $default stage"
  value       = aws_apigatewayv2_stage.default.id
}

output "log_group_name" {
  description = "Name of the CloudWatch Log Group for API Gateway access logs"
  value       = aws_cloudwatch_log_group.api_gw.name
}
