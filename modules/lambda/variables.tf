# =============================================================================
# modules/lambda/variables.tf
# =============================================================================

# --- Identity ---
variable "function_name" {
  description = "Name of the Lambda function. Used as-is — include env suffix at the call site (e.g. 'my-api-handler-dev')."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,64}$", var.function_name))
    error_message = "function_name must be 1-64 alphanumeric characters, hyphens, or underscores."
  }
}

variable "description" {
  description = "Human-readable description of what the function does."
  type        = string
  default     = ""
}

# --- Deployment Package ---
# Exactly one of (filename) or (s3_bucket + s3_key) must be provided.
# Terraform does not enforce mutual exclusivity natively, so we rely on
# Lambda's own API to error if neither or both are set.

variable "filename" {
  description = "Path to a local .zip file containing the function code. Mutually exclusive with s3_bucket/s3_key."
  type        = string
  default     = null
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 hash of the deployment package. Used to detect code changes. Generate with: filebase64sha256('path/to/package.zip')"
  type        = string
  default     = null
}

variable "s3_bucket" {
  description = "S3 bucket containing the deployment package. Use with s3_key."
  type        = string
  default     = null
}

variable "s3_key" {
  description = "S3 key of the deployment package zip. Use with s3_bucket."
  type        = string
  default     = null
}

# --- Runtime ---
variable "handler" {
  description = "Function entrypoint in the format file.method (e.g. 'index.handler' for Node, 'main.handler' for Python)."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier."
  type        = string
  default     = "python3.12"

  validation {
    condition = contains([
      "python3.10", "python3.11", "python3.12",
      "nodejs18.x", "nodejs20.x",
      "java17", "java21",
      "provided.al2023"
    ], var.runtime)
    error_message = "Unsupported runtime. See https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html"
  }
}

variable "timeout" {
  description = "Maximum execution time in seconds. Lambda hard limit is 900 (15 min)."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Memory allocated to the function in MB. CPU scales proportionally."
  type        = number
  default     = 128

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 MB and 10240 MB."
  }
}

# --- Configuration ---
variable "environment_variables" {
  description = "Map of environment variables injected into the function at runtime."
  type        = map(string)
  default     = {}
}

# --- VPC ---
# Pass null (the default) to run Lambda outside a VPC.
# Pass a vpc_config object to attach it to private subnets.
variable "vpc_config" {
  description = <<-EOT
    Optional VPC configuration. When set, the function runs inside the VPC
    and can reach private resources (RDS, ElastiCache, etc.).
    Requires subnet_ids in PRIVATE subnets and a security group that allows
    the function's outbound traffic.
    When null, the function runs in Lambda's default network with full
    internet access but no access to VPC-private resources.
  EOT
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

# --- IAM ---
variable "policy_json" {
  description = <<-EOT
    JSON string of an additional IAM policy to attach inline to the Lambda
    execution role. Use jsonencode() at the call site to build it cleanly.
    Example:
      policy_json = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
          Resource = aws_dynamodb_table.my_table.arn
        }]
      })
  EOT
  type    = string
  default = null
}

# --- Observability ---
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs. Set to 0 for indefinite retention."
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs (0, 1, 3, 5, 7, 14, 30, 60, 90...)."
  }
}
