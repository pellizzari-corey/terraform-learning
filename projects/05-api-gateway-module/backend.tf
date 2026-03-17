# =============================================================================
# backend.tf — Project 2.3: API Gateway Module
# =============================================================================

terraform {
  backend "s3" {
    bucket         = "tf-learning-state-184089812229-us-east-1"
    key            = "05-api-gateway-module/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-learning-locks"
    encrypt        = true
  }
}
