# =============================================================================
# main.tf — Project 1.2: Your First VPC (flat)
#
# PURPOSE: Build a production-ready VPC topology in a single flat directory
# before we refactor it into a reusable module in Project 2.1.
#
# ARCHITECTURE:
#   - 1 VPC
#   - 2 Public subnets  (one per AZ) — for load balancers, NAT gateways
#   - 2 Private subnets (one per AZ) — for Lambda, compute, databases
#   - 1 Internet Gateway — allows public subnets to reach the internet
#   - 1 NAT Gateway      — allows private subnets to make outbound calls
#   - Route tables wired to the correct subnets
#   - 3 Security Groups  — (bastion, lambda, http/https ingress)
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-learning"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

# -----------------------------------------------------------------------------
# Data source: look up the available AZs in the chosen region at plan time.
# Using a data source here means the config adapts to any region automatically
# instead of hard-coding AZ names like "us-east-1a".
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Required for private DNS resolution inside the VPC (e.g. Lambda → RDS)
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Public Subnets
# Spread across the first `var.az_count` AZs.
# map_public_ip_on_launch = true so EC2/NAT instances get a public IP.
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "public"
  }
}

# -----------------------------------------------------------------------------
# Private Subnets
# Offset the CIDR index by `var.az_count` so they don't overlap with public.
# These subnets do NOT get public IPs — only outbound via NAT.
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "private"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway — connects the VPC to the public internet
# One IGW per VPC (not per AZ).
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -----------------------------------------------------------------------------
# Elastic IP for the NAT Gateway
# A static public IP that the NAT gateway uses for outbound traffic.
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  # One EIP regardless of AZ count — we're using a single NAT GW to save cost.
  # In production you'd have one NAT GW per AZ for HA.
  domain = "vpc"

  # EIP depends on the IGW existing first
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway — sits in the FIRST public subnet, allows private subnets
# to make outbound internet calls (e.g. Lambda pulling packages from PyPI)
# without being directly reachable from the internet.
# -----------------------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Always place NAT GW in a public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public route table: all non-VPC traffic exits through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

# Private route table: all non-VPC traffic exits through the NAT gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

# Associate each public subnet with the public route table
resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate each private subnet with the private route table
resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security Groups
# Defined here as separate named resources so they're easy to reference
# by name in the outputs and in future module calls.
# -----------------------------------------------------------------------------

# -- Lambda Security Group --
# Allows outbound HTTPS (to call AWS APIs, fetch packages, etc.)
# No inbound rules — Lambda is invoked by AWS, not by direct network calls.
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-sg-lambda"
  description = "Security group for Lambda functions running inside the VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound traffic (Lambda needs to reach AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-lambda"
  }
}

# -- HTTP/HTTPS Ingress Security Group --
# For load balancers or API Gateway VPC endpoints that face the internet.
resource "aws_security_group" "http_ingress" {
  name        = "${var.project_name}-sg-http-ingress"
  description = "Allow inbound HTTP and HTTPS from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-http-ingress"
  }
}

# -- Bastion / Internal Security Group --
# A catch-all SG for internal VPC traffic. Resources tagged with this SG
# can accept traffic from other resources also in this SG.
resource "aws_security_group" "internal" {
  name        = "${var.project_name}-sg-internal"
  description = "Allow traffic between resources within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all traffic from within the same SG (VPC-internal)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-internal"
  }
}
