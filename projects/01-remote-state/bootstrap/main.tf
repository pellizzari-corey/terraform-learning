# =============================================================================
# BOOTSTRAP — Run this ONCE manually to create the S3 bucket and DynamoDB
# table that will store Terraform state for all future projects.
#
# HOW TO USE:
#   1. Make sure your AWS CLI is configured: `aws configure`
#   2. cd into this bootstrap/ directory
#   3. terraform init
#   4. terraform apply
#   5. Copy the outputs into ../backend.tf
#
# NOTE: This bootstrap config itself uses LOCAL state (no backend block).
#       That is intentional — you can't store state remotely before the
#       remote state infrastructure exists.
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
      Environment = "bootstrap"
    }
  }
}

# -----------------------------------------------------------------------------
# S3 Bucket — stores the .tfstate files
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "terraform_state" {
  # Bucket names must be globally unique. The random suffix handles that.
  bucket = "${var.state_bucket_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  # Prevent accidental deletion of this bucket which would lose all state
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so you can recover from bad applies or accidental deletes
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest using AES-256 (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block ALL public access — state files may contain sensitive values
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# DynamoDB Table — provides state locking to prevent concurrent applies
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # No need to provision capacity for low-traffic IaC use
  hash_key     = "LockID"          # This key name is required by Terraform

  attribute {
    name = "LockID"
    type = "S"
  }
}

# -----------------------------------------------------------------------------
# Data sources
# -----------------------------------------------------------------------------
data "aws_caller_identity" "current" {}
