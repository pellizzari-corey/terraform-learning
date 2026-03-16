# Project 1.2 — Your First VPC (flat)

## What you'll learn
- How to model a real AWS VPC topology in HCL
- `count` meta-argument for creating multiple similar resources
- `cidrsubnet()` built-in function for programmatic CIDR math
- Data sources (`aws_availability_zones`) — reading live AWS state at plan time
- `depends_on` — explicit dependency declaration
- Resource dependency graph (implicit vs explicit)
- `terraform state` commands to inspect what Terraform is tracking

---

## Architecture

```
VPC: 10.0.0.0/16
│
├── Public Subnet AZ-a  10.0.0.0/24  ──┐
├── Public Subnet AZ-b  10.0.1.0/24  ──┤── Internet Gateway ── Internet
│         │                             │
│    [NAT Gateway]                      │
│         │                             │
├── Private Subnet AZ-a 10.0.2.0/24  ──┤
└── Private Subnet AZ-b 10.0.3.0/24  ──┘
```

**Public subnets** — resources here get public IPs and can reach the internet
directly via the Internet Gateway. Used for NAT gateways, load balancers,
and any resource that needs to be reachable from outside the VPC.

**Private subnets** — no public IPs. Outbound-only internet access via the
NAT Gateway. Where Lambda functions, databases, and application servers live.

---

## Key Terraform Concepts in This Project

### `count` — creating multiple resources from one block
```hcl
resource "aws_subnet" "public" {
  count = var.az_count          # Creates 2 copies (indexes 0 and 1)

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
}
```
This creates `aws_subnet.public[0]` and `aws_subnet.public[1]`.
Reference them with `aws_subnet.public[*].id` (splat) or `aws_subnet.public[0].id`.

### `cidrsubnet()` — CIDR math without a calculator
```hcl
cidrsubnet("10.0.0.0/16", 8, 0)  # → 10.0.0.0/24
cidrsubnet("10.0.0.0/16", 8, 1)  # → 10.0.1.0/24
cidrsubnet("10.0.0.0/16", 8, 2)  # → 10.0.2.0/24
```
`newbits = 8` means "add 8 bits to the prefix" (16+8 = /24).
`netnum` is the index of the subnet within that new size.

### Data sources — reading AWS without creating anything
```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
# Use it as: data.aws_availability_zones.available.names[0]
```
Data sources are read-only. They query AWS at plan time and return values
your config can use. No resources are created.

### Implicit vs explicit dependencies
Terraform builds a dependency graph automatically from resource references:
```hcl
# IMPLICIT — Terraform sees aws_vpc.main.id and knows to create the VPC first
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id  # ← this reference creates the dependency
}

# EXPLICIT — for dependencies Terraform can't infer from references
resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.main]
}
```

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder with your actual bucket name from Project 1.1:
```bash
# Get it from the bootstrap outputs
cd ../01-remote-state/bootstrap
terraform output state_bucket_name
```

### Step 2 — Init & Plan
```bash
cd projects/02-flat-vpc
terraform init
terraform plan
```

Count the resources in the plan output. You should see **16 resources** to add:
- 1 VPC
- 2 public subnets + 2 private subnets
- 1 Internet Gateway
- 1 Elastic IP + 1 NAT Gateway
- 2 route tables + 4 route table associations
- 3 security groups

### Step 3 — Apply
```bash
terraform apply
```

### Step 4 — Inspect outputs
```bash
terraform output

# See a specific value
terraform output vpc_id

# See the full summary map
terraform output vpc_summary
```

### Step 5 — Inspect state
```bash
# List everything Terraform is tracking
terraform state list

# Inspect a specific resource (notice: real AWS IDs are stored here)
terraform state show aws_vpc.main
terraform state show 'aws_subnet.public[0]'
```

### Step 6 — Experiment: change az_count
In `terraform.tfvars`, change `az_count = 2` to `az_count = 3`.
Run `terraform plan` and observe:
- 1 new public subnet, 1 new private subnet proposed
- 2 new route table associations
- NAT Gateway and IGW are unchanged (they're not count-based)

Revert before continuing.

### Step 7 — Experiment: force a destroy-and-recreate
Change `vpc_cidr` from `10.0.0.0/16` to `10.1.0.0/16` and run `terraform plan`.

Notice that **everything** in the plan is `-/+` (replace). The VPC CIDR is
immutable — changing it requires destroying and recreating the entire VPC and
all its children. This is a critical concept: know which fields are immutable
before changing them in production.

Revert before continuing.

### Step 8 — Destroy
```bash
terraform destroy
```

The NAT Gateway takes ~60 seconds to delete. This is also why NAT Gateways
cost money even when idle — they're dedicated hardware, not serverless.

---

## Cost Notes

> ⚠️ This project creates resources that cost money while running:
> - **NAT Gateway**: ~$0.045/hour + $0.045/GB processed
> - **Elastic IP**: Free while attached to the NAT GW; $0.005/hour if unattached
>
> Always `terraform destroy` when you're done learning.
> The VPC, subnets, IGW, route tables, and security groups are **free**.

---

## What to Notice for Project 2.1

When we refactor this into a module, every `var.*` becomes a module input,
and every `output.*` becomes the module's interface. The actual resource
blocks stay nearly identical — modules are just a packaging boundary, not
a rewrite.

The `vpc_summary` output block especially foreshadows the module pattern:
it bundles all the IDs a caller would need into a single map.

---

## Next Up → Project 2.1: `vpc` Module

Take everything in this flat config and package it as a reusable module:
```
modules/
  vpc/
    main.tf       ← these resource blocks, mostly unchanged
    variables.tf  ← these variables become the module's input contract
    outputs.tf    ← these outputs become the module's public API
```
