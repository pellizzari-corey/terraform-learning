# =============================================================================
# outputs.tf — Project 2.1: VPC Module (root)
#
# Root module outputs surface module values to the CLI and to other configs
# that might reference this state via `terraform_remote_state`.
#
# Syntax: module.<module_label>.<output_name>
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (null if disabled)"
  value       = module.vpc.nat_gateway_public_ip
}

output "sg_lambda_id" {
  description = "Security group ID for Lambda functions"
  value       = module.vpc.sg_lambda_id
}

output "sg_http_ingress_id" {
  description = "Security group ID for HTTP/HTTPS ingress"
  value       = module.vpc.sg_http_ingress_id
}

output "sg_internal_id" {
  description = "Security group ID for internal VPC traffic"
  value       = module.vpc.sg_internal_id
}
