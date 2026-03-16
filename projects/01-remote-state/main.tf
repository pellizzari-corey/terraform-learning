# =============================================================================
# main.tf — Project 01: Remote State
#
# PURPOSE: Verify that your remote backend is wired up correctly.
# This project creates a single SSM Parameter as a "Hello World" resource —
# cheap, harmless, and easy to verify in the AWS Console.
#
# After `terraform apply`, check:
#   1. AWS Console → S3 → your bucket → 01-remote-state/terraform.tfstate exists
#   2. AWS Console → Systems Manager → Parameter Store → /tf-learning/hello exists
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend config lives in backend.tf (kept separate so it's easy to swap)
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
# A simple SSM Parameter — our "Hello World" resource to confirm state works
# -----------------------------------------------------------------------------
resource "aws_ssm_parameter" "hello" {
  name  = "/tf-learning/hello-v2"
  type  = "String"
  value = "Remote state is working! Deployed at ${timestamp()}"

  lifecycle {
    # timestamp() changes on every plan, so ignore it after initial creation
    ignore_changes = [value]
  }
}
