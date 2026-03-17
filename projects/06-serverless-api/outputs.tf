# =============================================================================
# outputs.tf — Project 3: Full Serverless API
# =============================================================================

# --- Endpoints ---
output "api_base_url" {
  description = "Base URL of the HTTP API"
  value       = module.api_gateway.invoke_url
}

output "health_endpoint" {
  description = "Health check endpoint"
  value       = "${module.api_gateway.invoke_url}/"
}

output "products_endpoint" {
  description = "Products list endpoint"
  value       = "${module.api_gateway.invoke_url}/products"
}

# --- DynamoDB ---
output "dynamodb_table_name" {
  description = "Name of the DynamoDB products table"
  value       = aws_dynamodb_table.products.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB products table"
  value       = aws_dynamodb_table.products.arn
}

# --- Lambda ---
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch Log Group for Lambda"
  value       = module.lambda.log_group_name
}

# --- API Gateway ---
output "api_log_group" {
  description = "CloudWatch Log Group for API Gateway access logs"
  value       = module.api_gateway.log_group_name
}

output "api_id" {
  description = "API Gateway ID"
  value       = module.api_gateway.api_id
}

# --- VPC ---
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# --- Convenience: full curl test suite ---
output "curl_examples" {
  description = "Ready-to-run curl commands for manual testing"
  value       = <<-EOT

    # Health check
    curl ${module.api_gateway.invoke_url}/

    # List products (empty at first)
    curl ${module.api_gateway.invoke_url}/products

    # Create a product
    curl -X POST ${module.api_gateway.invoke_url}/products \
      -H "Content-Type: application/json" \
      -d '{"name": "Widget Pro", "price": 29.99}'

    # Get a single product (replace {id} with the id from the create response)
    curl ${module.api_gateway.invoke_url}/products/{id}

  EOT
}
