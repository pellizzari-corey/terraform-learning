# =============================================================================
# variables.tf — Project 2.3: API Gateway Module
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Short project name used to prefix all resources"
  type        = string
  default     = "tf-learning"
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for the VPC Lambda. Set false to reduce cost; VPC Lambda will lose outbound internet access."
  type        = bool
  default     = true
}
