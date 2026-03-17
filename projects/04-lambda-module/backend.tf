# =============================================================================
# backend.tf — Project 2.2: Lambda Module
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_your_state_bucket_name"
    key            = "04-lambda-module/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
