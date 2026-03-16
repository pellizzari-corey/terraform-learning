# =============================================================================
# backend.tf — Project 2.1: VPC Module
# Only the `key` changes from project to project.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_your_state_bucket_name"
    key            = "03-vpc-module/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
