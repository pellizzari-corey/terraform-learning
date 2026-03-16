# =============================================================================
# variables.tf — Project 01: Remote State
# =============================================================================

variable "aws_region" {
  description = "AWS region for this project"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (used in default_tags)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}
