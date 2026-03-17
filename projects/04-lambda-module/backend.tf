# =============================================================================
# backend.tf — Project 2.2: Lambda Module
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "tf-learning-state-184089812229-us-east-1"
    key            = "04-lambda-module/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
