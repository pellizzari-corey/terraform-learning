# Project 2.1 — VPC Module

## What you'll learn
- How to structure a reusable Terraform module
- The input/output contract pattern (variables.tf + outputs.tf as an API)
- What the `module {}` call block looks like and how arguments map to variables
- How `terraform state list` shows module-namespaced resource addresses
- The `enable_nat_gateway` toggle pattern — conditional resource creation with `count`
- How to pass module outputs up to the root and on to other modules

---

## The Core Mental Model: Modules ≈ CDK Constructs

| CDK | Terraform |
|---|---|
| `new VpcConstruct(this, 'Vpc', props)` | `module "vpc" { source = "../../modules/vpc" }` |
| `Props` interface | `variables.tf` |
| `this.vpcId` / public properties | `outputs.tf` |
| `super(scope, id, props)` | implicit — Terraform handles scope |
| Construct ID (`'Vpc'`) | module label (`"vpc"`) |

The key difference: CDK constructs are instantiated in code flow. Terraform modules are declared as configuration blocks. Both result in a tree of resources with a clean input/output interface.

---

## File Structure

```
terraform-learning/
├── modules/
│   └── vpc/                  ← THE MODULE (reusable, no provider/backend)
│       ├── main.tf            #   resource definitions
│       ├── variables.tf       #   input contract
│       └── outputs.tf         #   output contract
└── projects/
    └── 03-vpc-module/         ← ROOT MODULE (caller, has provider + backend)
        ├── main.tf            #   calls module.vpc
        ├── variables.tf
        ├── outputs.tf         #   surfaces module.vpc.* to CLI
        ├── backend.tf
        └── terraform.tfvars
```

**The rule**: modules live in `modules/`. They have NO `terraform {}`, `provider {}`, or `backend {}` blocks. The root module in `projects/` owns all of that.

---

## What Changed from 02-flat-vpc

### Root `main.tf` went from ~150 lines → 15 lines
All the resource blocks moved into `modules/vpc/main.tf`. The root is now purely declarative composition:

```hcl
# Before (flat) — root main.tf had all the resources
resource "aws_vpc" "main" { ... }
resource "aws_subnet" "public" { ... }
# ... 14 more resource blocks

# After (module) — root main.tf just calls the module
module "vpc" {
  source             = "../../modules/vpc"
  name               = "${var.project_name}-${var.environment}"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  enable_nat_gateway = var.enable_nat_gateway
}
```

### One new feature: `enable_nat_gateway`
The flat VPC always created a NAT Gateway. The module adds a toggle:

```hcl
# In modules/vpc/main.tf
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0   # conditional creation
  ...
}
```

Set `enable_nat_gateway = false` in `terraform.tfvars` to skip the NAT GW
and save ~$0.045/hr in dev environments.

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder with your state bucket name from Project 1.1.

### Step 2 — Init
```bash
cd projects/03-vpc-module
terraform init
```

During init, Terraform resolves the local module source path and copies it
into `.terraform/modules/`. Run `ls .terraform/modules/` to see it.

### Step 3 — Plan
```bash
terraform plan
```

Notice the resource addresses now have a module prefix:
```
module.vpc.aws_vpc.main
module.vpc.aws_subnet.public[0]
module.vpc.aws_nat_gateway.main[0]
```

This namespacing is what makes modules composable — if you called the vpc
module twice (e.g. for a second VPC), their resources would be at
`module.vpc_primary.*` and `module.vpc_secondary.*` with no conflicts.

### Step 4 — Apply
```bash
terraform apply
```

### Step 5 — Inspect module state
```bash
# All resources are namespaced under module.vpc
terraform state list

# Inspect a specific module resource
terraform state show 'module.vpc.aws_vpc.main'
terraform state show 'module.vpc.aws_subnet.private[0]'

# See root-level outputs (which pass through from the module)
terraform output
terraform output private_subnet_ids
```

### Step 6 — Try the NAT Gateway toggle
In `terraform.tfvars`, set `enable_nat_gateway = false` and run:
```bash
terraform plan
```

The plan should show:
- `module.vpc.aws_nat_gateway.main[0]` will be **destroyed**
- `module.vpc.aws_eip.nat[0]` will be **destroyed**
- `module.vpc.aws_route_table.private` will be **updated** (NAT route removed)
- Everything else: no change

This is the `count = condition ? 1 : 0` pattern — toggle a whole resource
on/off with a boolean. Revert before continuing.

### Step 7 — Validate the module in isolation
```bash
cd modules/vpc
terraform init   # just validates syntax & provider requirements
terraform validate
```

`terraform validate` checks HCL syntax and internal references without
needing AWS credentials. Useful in CI pipelines to catch typos early.

### Step 8 — Destroy
```bash
cd projects/03-vpc-module
terraform destroy
```

---

## Module Input/Output Contract

### Inputs (`variables.tf`)
| Variable | Required | Default | Purpose |
|---|---|---|---|
| `name` | ✅ yes | — | Resource name prefix |
| `environment` | ✅ yes | — | Tag value, validation enforced |
| `vpc_cidr` | no | `10.0.0.0/16` | VPC CIDR range |
| `az_count` | no | `2` | Subnet spread across AZs |
| `enable_nat_gateway` | no | `true` | Cost toggle for NAT GW |

### Outputs (`outputs.tf`)
| Output | Type | Description |
|---|---|---|
| `vpc_id` | `string` | VPC ID |
| `public_subnet_ids` | `list(string)` | Public subnet IDs |
| `private_subnet_ids` | `list(string)` | Private subnet IDs |
| `nat_gateway_id` | `string\|null` | NAT GW ID (null if disabled) |
| `nat_gateway_public_ip` | `string\|null` | NAT GW public IP |
| `sg_lambda_id` | `string` | Lambda security group |
| `sg_http_ingress_id` | `string` | HTTP/HTTPS ingress SG |
| `sg_internal_id` | `string` | Internal VPC SG |

These outputs are the **stable interface** of this module. Callers depend on
them — don't rename or remove them without a migration plan.

---

## Referencing Module Outputs in a Caller

In a future project (e.g. the Lambda module), you'll wire the VPC outputs
directly into another module call:

```hcl
module "vpc" {
  source = "../../modules/vpc"
  name   = "myapp-dev"
  ...
}

module "lambda" {
  source            = "../../modules/lambda"
  vpc_id            = module.vpc.vpc_id                # ← module output as input
  subnet_ids        = module.vpc.private_subnet_ids    # ← list passed directly
  security_group_id = module.vpc.sg_lambda_id
  ...
}
```

This chaining is exactly how Phase 3's serverless API project will be composed.

---

## Next Up → Project 2.2: `lambda` Module

Build the Lambda + IAM module using the same pattern:
- `modules/lambda/main.tf` — `aws_lambda_function`, IAM role, IAM policy
- `modules/lambda/variables.tf` — function name, runtime, handler, env vars, VPC config
- `modules/lambda/outputs.tf` — `function_arn`, `invoke_arn`, `function_name`
