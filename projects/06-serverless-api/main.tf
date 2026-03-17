# =============================================================================
# main.tf — Project 3: Full Serverless API
#
# WHAT THIS DEMONSTRATES:
#   1. All three modules (vpc, lambda, api_gateway) composed in one root
#   2. A real DynamoDB table managed alongside the compute layer
#   3. IAM policy built from live resource ARNs (not hardcoded strings)
#   4. Environment variables wiring Terraform outputs into Lambda config
#   5. The full request path: Internet → API GW → Lambda → DynamoDB
#
# ARCHITECTURE:
#   Internet
#     └── API Gateway (HTTP API)
#           └── Lambda (private subnet, Python 3.12)
#                 └── DynamoDB (products table)
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-learning"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# -----------------------------------------------------------------------------
# Zip the Lambda source at plan time
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

# -----------------------------------------------------------------------------
# DynamoDB — Products table
#
# Defined in the root module (not a child module) because it's a data
# resource tightly coupled to this specific application. Generic compute
# modules (lambda, vpc) shouldn't know about application-level tables.
#
# PAY_PER_REQUEST: no capacity planning needed, scales to zero when idle.
# Perfect for dev/learning — you pay only for actual reads and writes.
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "products" {
  name         = "${var.project_name}-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Protect the table from accidental terraform destroy in prod
  lifecycle {
    prevent_destroy = false # Set true in prod
  }

  tags = {
    Name = "${var.project_name}-products-${var.environment}"
  }
}

# -----------------------------------------------------------------------------
# VPC module
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name               = "${var.project_name}-${var.environment}"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
}

# -----------------------------------------------------------------------------
# Lambda module
#
# Notice how the DynamoDB table ARN flows directly into policy_json —
# Terraform resolves this reference at apply time, so the policy always
# points at the exact table this config created, never a hardcoded ARN.
# -----------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/lambda"

  function_name    = "${var.project_name}-api-${var.environment}"
  description      = "Products API handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "handler.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256

  # Inject the table name so the Lambda doesn't need to hardcode it
  environment_variables = {
    PRODUCTS_TABLE = aws_dynamodb_table.products.name
    STAGE          = var.environment
  }

  # DynamoDB read/write permissions scoped to only this table
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query",
        ]
        # Reference the live ARN — no hardcoding
        Resource = aws_dynamodb_table.products.arn
      }
    ]
  })

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.sg_lambda_id]
  }

  log_retention_days = var.log_retention_days
}

# -----------------------------------------------------------------------------
# API Gateway module
# -----------------------------------------------------------------------------
module "api_gateway" {
  source = "../../modules/api_gateway"

  name        = "${var.project_name}-api-${var.environment}"
  description = "Products API — ${var.environment}"

  routes = {
    "GET /" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "GET /products" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "GET /products/{id}" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "POST /products" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
  }

  cors_configuration = {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  log_retention_days = var.log_retention_days
}
