# =============================================================================
# modules/vpc/variables.tf
#
# These are the module's INPUT CONTRACT — the explicit interface that any
# caller must satisfy. Think of these as the constructor parameters for a
# CDK Construct's Props interface.
#
# RULE: Modules should have NO defaults for identity/naming vars (name,
# environment) so callers are forced to be explicit. Provide defaults only
# for optional behaviour flags (enable_nat_gateway) or safe fallbacks
# (vpc_cidr, az_count).
# =============================================================================

variable "name" {
  description = "Short identifier used as a prefix for all resource names and tags. Should be unique per deployment (e.g. 'myapp-dev', 'myapp-prod')."
  type        = string

  validation {
    condition     = length(var.name) <= 32 && can(regex("^[a-z0-9-]+$", var.name))
    error_message = "name must be lowercase alphanumeric with hyphens, max 32 characters."
  }
}

variable "environment" {
  description = "Deployment environment label applied to all resource tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a /16 so cidrsubnet() can carve /24 subnets."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to deploy into. Creates one public and one private subnet per AZ."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 4
    error_message = "az_count must be between 1 and 4."
  }
}

variable "enable_nat_gateway" {
  description = <<-EOT
    Whether to create a NAT Gateway for private subnet outbound access.
    Set to false in dev/test environments to avoid the ~$0.045/hr NAT cost.
    When false, Lambda functions in private subnets cannot reach the internet.
  EOT
  type        = bool
  default     = true
}
