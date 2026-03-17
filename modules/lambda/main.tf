# =============================================================================
# modules/lambda/main.tf
#
# PURPOSE: A reusable module that provisions a Lambda function with:
#   - IAM execution role + configurable inline policies
#   - Optional VPC attachment (subnet + security group wiring)
#   - Optional environment variables
#   - CloudWatch Log Group with configurable retention
#
# CALLER SUPPLIES: the zipped deployment package path or S3 location,
# the handler + runtime, and any VPC/env config.
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Execution Role
# Every Lambda needs a role. The trust policy allows the Lambda service
# to assume this role when invoking the function.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.function_name}-role"
  }
}

# -----------------------------------------------------------------------------
# Managed Policy Attachments
#
# AWSLambdaBasicExecutionRole    — allows writing logs to CloudWatch (always)
# AWSLambdaVPCAccessExecutionRole — allows creating/deleting ENIs for VPC
#                                   attachment (only when vpc_config is set)
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = var.vpc_config != null ? 1 : 0

  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -----------------------------------------------------------------------------
# Inline Policy — attach additional permissions passed in by the caller
# (e.g. DynamoDB read, S3 put, SSM GetParameter)
# Only created when the caller provides a non-null policy_json.
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy" "extra" {
  count = var.policy_json != null ? 1 : 0

  name   = "${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = var.policy_json
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
#
# Lambda auto-creates /aws/lambda/<name> on first invocation, but managing
# it in Terraform gives you retention control and prevents it from persisting
# after a destroy.
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.lambda.arn

  # Deployment package — supports local zip or S3
  filename         = var.filename
  s3_bucket        = var.s3_bucket
  s3_key           = var.s3_key
  source_code_hash = var.source_code_hash

  handler     = var.handler
  runtime     = var.runtime
  timeout     = var.timeout
  memory_size = var.memory_size

  # Environment variables — only set the block when vars are provided
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  # VPC config — only set the block when vpc_config is provided
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Lambda must not be created before the log group and IAM role are ready
  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic_execution,
  ]

  tags = {
    Name = var.function_name
  }
}
