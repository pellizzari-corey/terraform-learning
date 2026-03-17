# =============================================================================
# outputs.tf — Project 4: Multi-Environment
# =============================================================================

output "environment" {
  description = "The environment this stack was deployed to"
  value       = var.environment
}

output "api_base_url" {
  description = "Base URL of the HTTP API"
  value       = module.api_gateway.invoke_url
}

output "products_endpoint" {
  description = "Products list endpoint"
  value       = "${module.api_gateway.invoke_url}/products"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB products table"
  value       = local.dynamodb_table_name
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch Log Group for Lambda"
  value       = module.lambda.log_group_name
}

output "api_log_group" {
  description = "CloudWatch Log Group for API Gateway"
  value       = module.api_gateway.log_group_name
}

output "curl_examples" {
  description = "Ready-to-run curl commands"
  value       = <<-EOT

    # Health check
    curl ${module.api_gateway.invoke_url}/

    # List products
    curl ${module.api_gateway.invoke_url}/products

    # Create a product
    curl -X POST ${module.api_gateway.invoke_url}/products \
      -H "Content-Type: application/json" \
      -d '{"name": "Widget Pro", "price": 29.99}'

  EOT
}
