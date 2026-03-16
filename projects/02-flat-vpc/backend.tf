# =============================================================================
# backend.tf — Project 1.2: Flat VPC
#
# Same S3 bucket as Project 1.1 — only the `key` changes.
# Each project writes its own isolated .tfstate file into the shared bucket.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_your_state_bucket_name"
    key            = "02-flat-vpc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
