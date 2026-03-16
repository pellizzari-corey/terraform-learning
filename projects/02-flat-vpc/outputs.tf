# =============================================================================
# outputs.tf — Project 1.2: Flat VPC
#
# These outputs do two things:
#   1. Let you inspect values after apply: `terraform output`
#   2. Foreshadow what the vpc MODULE will export in Project 2.1 —
#      when you refactor, these become the module's output contract.
# =============================================================================

# --- VPC ---
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# --- Subnets ---
output "public_subnet_ids" {
  description = "List of public subnet IDs (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (one per AZ)"
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

# --- Gateways ---
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (useful for allowlisting in external services)"
  value       = aws_eip.nat.public_ip
}

# --- Security Groups ---
output "sg_lambda_id" {
  description = "Security group ID for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "sg_http_ingress_id" {
  description = "Security group ID for HTTP/HTTPS ingress (load balancers, API GW VPC endpoints)"
  value       = aws_security_group.http_ingress.id
}

output "sg_internal_id" {
  description = "Security group ID for internal VPC traffic"
  value       = aws_security_group.internal.id
}

# --- Convenience: full map for passing to other modules ---
output "vpc_summary" {
  description = "Map of key VPC values — useful for passing the whole thing to another module"
  value = {
    vpc_id             = aws_vpc.main.id
    public_subnet_ids  = aws_subnet.public[*].id
    private_subnet_ids = aws_subnet.private[*].id
    sg_lambda_id       = aws_security_group.lambda.id
    sg_http_ingress_id = aws_security_group.http_ingress.id
    sg_internal_id     = aws_security_group.internal.id
  }
}
