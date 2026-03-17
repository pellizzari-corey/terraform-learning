# =============================================================================
# main.tf — Project 2.2: Lambda Module
#
# WHAT THIS DEMONSTRATES:
#   1. Using the `archive_file` data source to zip local source code
#      at plan time — no manual zipping step required
#   2. Calling the lambda module with and without VPC config
#   3. Passing a jsonencode() IAM policy into the module
#   4. Wiring the vpc module output directly into the lambda module input
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
# archive_file data source
#
# Zips the src/ directory at plan time and writes it to /tmp.
# The resulting zip path is passed to the lambda module as `filename`.
#
# source_code_hash detects when the zip contents change so Terraform knows
# to push a new deployment — without it, code changes would be ignored.
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}

# -----------------------------------------------------------------------------
# VPC module — reusing the module we built in Project 2.1
# Lambda #2 (vpc_lambda) will be attached to this VPC's private subnets.
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
# Lambda #1 — runs OUTSIDE a VPC (no vpc_config)
#
# Use case: functions that only need to call public AWS APIs (S3, DynamoDB,
# SSM) and don't need to reach private VPC resources. Simpler and cheaper
# (no NAT Gateway required).
# -----------------------------------------------------------------------------
module "lambda_public" {
  source = "../../modules/lambda"

  function_name = "${var.project_name}-public-${var.environment}"
  description   = "Lambda running outside VPC — demonstrates public network mode"
  filename      = data.archive_file.lambda_zip.output_path

  # source_code_hash triggers a redeployment whenever src/ files change
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler = "handler.handler"
  runtime = "python3.12"
  timeout = 30

  environment_variables = {
    GREETING = "Hello"
    STAGE    = var.environment
  }

  log_retention_days = 7
}

# -----------------------------------------------------------------------------
# Lambda #2 — runs INSIDE the VPC on private subnets
#
# Use case: functions that need to reach RDS, ElastiCache, or other
# VPC-private resources. Requires NAT Gateway for outbound internet access.
# -----------------------------------------------------------------------------
module "lambda_vpc" {
  source = "../../modules/lambda"

  function_name = "${var.project_name}-vpc-${var.environment}"
  description   = "Lambda running inside VPC private subnets"
  filename      = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "handler.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256

  environment_variables = {
    GREETING = "Hello from inside the VPC"
    STAGE    = var.environment
  }

  # Wire in the VPC module outputs directly — this is the module chaining pattern
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.sg_lambda_id]
  }

  # Grant this function permission to read SSM parameters (example extra policy)
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })

  log_retention_days = 7
}
