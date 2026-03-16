# =============================================================================
# modules/vpc/outputs.tf
#
# These are the module's OUTPUT CONTRACT — the values it exposes to callers.
# Callers reference these as: module.vpc.vpc_id, module.vpc.private_subnet_ids
#
# Expose everything a downstream module (lambda, ecs, rds) would ever need
# so callers never have to reach inside the module with a data source.
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs, one per AZ"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs, one per AZ"
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (null if enable_nat_gateway = false)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (null if enable_nat_gateway = false)"
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "sg_lambda_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "sg_http_ingress_id" {
  description = "Security group ID for HTTP/HTTPS ingress"
  value       = aws_security_group.http_ingress.id
}

output "sg_internal_id" {
  description = "Security group ID for internal VPC traffic"
  value       = aws_security_group.internal.id
}
