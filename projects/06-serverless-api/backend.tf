# =============================================================================
# backend.tf — Project 3: Full Serverless API
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "tf-learning-state-184089812229-us-east-1"
    key            = "06-serverless-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
