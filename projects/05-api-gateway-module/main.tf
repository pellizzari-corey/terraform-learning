# =============================================================================
# main.tf — Project 2.3: API Gateway Module
#
# WHAT THIS DEMONSTRATES:
#   1. Calling all three modules together: vpc + lambda + api_gateway
#   2. for_each on the routes variable — multiple routes, one module call
#   3. CORS configuration passed through the module
#   4. How invoke_url flows out as a usable endpoint you can curl immediately
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
# Zip the Lambda source
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

# -----------------------------------------------------------------------------
# VPC — reusing the module from 2.1
# Lambda runs in private subnets; API Gateway is fully managed (no VPC needed)
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name               = "${var.project_name}-${var.environment}"
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 2
  enable_nat_gateway = var.enable_nat_gateway
}

# -----------------------------------------------------------------------------
# Lambda — reusing the module from 2.2
# One function handles all routes (see src/handler.py for routing logic)
# -----------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/lambda"

  function_name    = "${var.project_name}-api-${var.environment}"
  description      = "API handler for the tf-learning HTTP API"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "handler.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 128

  environment_variables = {
    STAGE = var.environment
  }

  # Attach to private subnets so it could reach RDS/ElastiCache in future
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.sg_lambda_id]
  }

  log_retention_days = 7
}

# -----------------------------------------------------------------------------
# API Gateway — reusing the module we just built
#
# routes is a map: route key string -> { invoke_arn, function_name }
# All three routes point at the same Lambda here; the handler uses the
# path/method from the event to dispatch internally.
# -----------------------------------------------------------------------------
module "api_gateway" {
  source = "../../modules/api_gateway"

  name        = "${var.project_name}-api-${var.environment}"
  description = "HTTP API for tf-learning project"

  routes = {
    "GET /hello" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "GET /items" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "POST /items" = {
      invoke_arn    = module.lambda.invoke_arn
      function_name = module.lambda.function_name
    }
    "DELETE /items" = {
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

  log_retention_days = 7
}
