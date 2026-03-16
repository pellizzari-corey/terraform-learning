# =============================================================================
# main.tf — Project 2.1: VPC Module (root module / caller)
#
# PURPOSE: This is the ROOT MODULE — the entry point for terraform apply.
# It calls the vpc child module and wires inputs to it.
#
# KEY SHIFT FROM 1.2:
#   - No VPC resource blocks here at all
#   - All networking lives inside modules/vpc/
#   - This file is purely COMPOSITION — declaring what to build and how to
#     configure it, not how to build it
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
# Call the VPC module
#
# `source` is the path to the module directory relative to this file.
# For local modules: "../../../modules/vpc"
# For registry modules: "terraform-aws-modules/vpc/aws"
#
# Every variable in modules/vpc/variables.tf must be satisfied here —
# either explicitly or via a default. Terraform will error on missing required
# vars at plan time.
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  # --- Required inputs (no defaults in the module) ---
  name        = "${var.project_name}-${var.environment}"
  environment = var.environment

  # --- Optional inputs (module has defaults, we're overriding) ---
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
}
