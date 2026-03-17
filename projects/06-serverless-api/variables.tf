# =============================================================================
# variables.tf — Project 3: Full Serverless API
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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread subnets across"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway. Required for VPC Lambda outbound access."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for both Lambda and API Gateway"
  type        = number
  default     = 14
}
