# =============================================================================
# backend.tf — Project 2.1: VPC Module
# Only the `key` changes from project to project.
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "tf-learning-state-184089812229-us-east-1"
    key            = "03-vpc-module/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
