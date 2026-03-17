# =============================================================================
# variables.tf — Project 4: Multi-Environment
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment — used in all resource names and tags"
  type        = string

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
  description = "CIDR block for the VPC. Use different ranges per environment to allow future VPC peering."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread subnets across. Use 1 in dev to reduce cost, 2+ in prod for redundancy."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count must be between 1 and 4."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway. Set false in dev to save ~$0.045/hr."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days. Use shorter periods in dev, longer in prod for audit trails."
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}

variable "prevent_table_destroy" {
  description = <<-EOT
    Whether to protect the DynamoDB table from accidental terraform destroy.
    Set true in prod to prevent data loss.
    Set false in dev for frictionless teardowns.
    See main.tf for the two-resource-block pattern this requires.
  EOT
  type        = bool
  default     = false
}
