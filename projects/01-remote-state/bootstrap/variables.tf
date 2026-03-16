# =============================================================================
# variables.tf — Bootstrap inputs
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy the remote state infrastructure into"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the S3 bucket name. Account ID and region are appended automatically to ensure global uniqueness."
  type        = string
  default     = "tf-learning-state"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking"
  type        = string
  default     = "tf-learning-locks"
}
