# =============================================================================
# backend.tf — Project 4: Multi-Environment
#
# PARTIAL BACKEND CONFIGURATION
#
# The state key must differ per environment, but backend blocks don't support
# variable interpolation (you can't write key = "07/${var.environment}/...").
#
# The solution is a partial backend config — leave `key` out of this file
# and pass it on the command line with -backend-config:
#
#   Dev:
#     terraform init -backend-config="key=07-multi-env/dev/terraform.tfstate"
#
#   Prod:
#     terraform init -backend-config="key=07-multi-env/prod/terraform.tfstate"
#
# Each environment gets a completely isolated state file in the same bucket.
# Terraform must be re-initialized (terraform init) when switching environments.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_your_state_bucket_name"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
    # key is intentionally omitted — passed via -backend-config at init time
  }
}
