# =============================================================================
# variables.tf — Project 1.2: Flat VPC
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label applied to all tags"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Short name used as a prefix for all resource names"
  type        = string
  default     = "tf-learning"
}

variable "vpc_cidr" {
  description = <<-EOT
    CIDR block for the VPC.
    Must be a /16 for the cidrsubnet() calls in main.tf to carve out /24 subnets cleanly.
    Example: "10.0.0.0/16" gives subnets 10.0.0.0/24, 10.0.1.0/24, etc.
  EOT
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block (e.g. 10.0.0.0/16)."
  }
}

variable "az_count" {
  description = <<-EOT
    Number of Availability Zones to spread subnets across.
    Each AZ gets one public subnet and one private subnet.
    Must not exceed the number of AZs available in the chosen region.
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count must be between 1 and 4."
  }
}
