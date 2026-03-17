# =============================================================================
# main.tf — Project 4: Multi-Environment
#
# THIS FILE IS IDENTICAL IN STRUCTURE TO PROJECT 3.
# That's the point — the code doesn't change between environments.
# Only the tfvars file changes. Terraform + the modules handle the rest.
#
# Deploy to dev:  terraform apply -var-file=environments/dev.tfvars
# Deploy to prod: terraform apply -var-file=environments/prod.tfvars
#
# Each environment gets:
#   - Its own isolated state file (different backend key)
#   - Its own set of AWS resources (prefixed with the environment name)
#   - Its own DynamoDB table, Lambda function, API Gateway, VPC
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

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

# -----------------------------------------------------------------------------
# DynamoDB
#
# prevent_destroy is driven by a variable so dev and prod behave differently.
# In dev: terraform destroy works freely.
# In prod: terraform destroy errors with a clear message before touching the table.
#
# NOTE: lifecycle blocks cannot use dynamic expressions directly — this is a
# known Terraform limitation. The workaround is to use two resource blocks
# with count, one with and one without prevent_destroy, toggled by the var.
# See the README for a full explanation of this pattern.
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "products" {
  count = var.prevent_table_destroy ? 0 : 1

  name         = "${var.project_name}-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name = "${var.project_name}-products-${var.environment}"
  }
}

resource "aws_dynamodb_table" "products_protected" {
  count = var.prevent_table_destroy ? 1 : 0

  name         = "${var.project_name}-products-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.project_name}-products-${var.environment}"
  }
}

# Local to unify the two table resources into a single reference
# so the rest of the config doesn't need to care which block created it
locals {
  dynamodb_table_name = var.prevent_table_destroy ? aws_dynamodb_table.products_protected[0].name : aws_dynamodb_table.products[0].name
  dynamodb_table_arn  = var.prevent_table_destroy ? aws_dynamodb_table.products_protected[0].arn : aws_dynamodb_table.products[0].arn
}

# -----------------------------------------------------------------------------
# VPC
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
# Lambda
# -----------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/lambda"

  function_name    = "${var.project_name}-api-${var.environment}"
  description      = "Products API handler — ${var.environment}"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "handler.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = var.environment == "prod" ? 512 : 256

  environment_variables = {
    PRODUCTS_TABLE = local.dynamodb_table_name
    STAGE          = var.environment
  }

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
        Resource = local.dynamodb_table_arn
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
# API Gateway
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
