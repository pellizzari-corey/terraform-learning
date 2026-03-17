# =============================================================================
# modules/vpc/main.tf
#
# PURPOSE: A reusable VPC module. Callers pass in variables; this module
# creates the full network topology and exposes IDs via outputs.
#
# COMPARED TO 02-flat-vpc/main.tf:
#   - No `terraform {}` block       — modules don't declare providers/backends
#   - No `provider {}` block        — the root module's provider is inherited
#   - Variable references unchanged — var.vpc_cidr still works exactly the same
#   - Resource blocks unchanged     — the networking logic is identical
#
# The ONLY structural difference is that this directory is called as a module
# by a root config, rather than being run directly with terraform apply.
# =============================================================================

# -----------------------------------------------------------------------------
# Data source — resolve AZ names at plan time
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-private-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "private"
  }
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# -----------------------------------------------------------------------------
# NAT Gateway (created only when var.enable_nat_gateway = true)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name = "${var.name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.name}-nat-gw"
  }
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name}-rt-public"
  }
}

# Private route table with NAT route (only when NAT GW is enabled)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }

  tags = {
    Name = "${var.name}-rt-private"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------
resource "aws_security_group" "lambda" {
  name        = "${var.name}-sg-lambda"
  description = "Security group for Lambda functions running inside the VPC"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg-lambda" }
}

resource "aws_security_group" "http_ingress" {
  name        = "${var.name}-sg-http-ingress"
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

  tags = { Name = "${var.name}-sg-http-ingress" }
}

resource "aws_security_group" "internal" {
  name        = "${var.name}-sg-internal"
  description = "Allow traffic between resources within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Self-referencing - internal VPC traffic only"
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

  tags = { Name = "${var.name}-sg-internal" }
}

# -----------------------------------------------------------------------------
# ENI Cleanup — runs before destroy to detach/delete Lambda ENIs that AWS
# leaves behind, which would otherwise block SG and subnet deletion.
# -----------------------------------------------------------------------------
resource "null_resource" "eni_cleanup" {
  triggers = {
    vpc_id        = aws_vpc.main.id
    sg_lambda_id  = aws_security_group.lambda.id
    region        = data.aws_availability_zones.available.id
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue

    command = <<-EOT
      aws ec2 describe-network-interfaces \
        --region ${self.triggers.region} \
        --filters \
          Name=vpc-id,Values=${self.triggers.vpc_id} \
          Name=group-id,Values=${self.triggers.sg_lambda_id} \
          Name=status,Values=available \
        --query 'NetworkInterfaces[*].NetworkInterfaceId' \
        --output text \
      | tr '\t' '\n' \
      | xargs -r -I{} aws ec2 delete-network-interface \
          --region ${self.triggers.region} \
          --network-interface-id {}
    EOT
  }
}