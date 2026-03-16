# =============================================================================
# outputs.tf — Values you'll need to copy into backend.tf for future projects
# =============================================================================

output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state. Paste this into backend.tf → bucket."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket (useful for IAM policies)"
  value       = aws_s3_bucket.terraform_state.arn
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table. Paste this into backend.tf → dynamodb_table."
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "Region these resources were created in. Paste this into backend.tf → region."
  value       = var.aws_region
}

# Convenience: print the full backend block to copy-paste
output "backend_config_snippet" {
  description = "Ready-to-paste backend block for all future projects"
  value       = <<-EOT
    # Copy this into your future projects' backend.tf:

    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "<project-name>/terraform.tfstate"
        region         = "${var.aws_region}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
        encrypt        = true
      }
    }
  EOT
}
