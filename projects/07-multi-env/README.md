# Project 4 — Multi-Environment (dev / prod)

## What you'll learn
- `tfvars` files as the environment switching mechanism
- Partial backend configuration — passing `key` via `-backend-config`
- State isolation per environment in the same S3 bucket
- The `prevent_destroy` lifecycle limitation and the two-resource-block workaround
- `locals` to unify conditional resource references into a single name
- Environment-specific resource sizing (Lambda memory, AZ count, log retention)
- The `terraform init -reconfigure` workflow when switching environments

---

## The Core Pattern

```
One set of .tf files
       +
environments/dev.tfvars   ← cost-optimized, disposable
environments/prod.tfvars  ← resilient, protected

       =

Two completely isolated stacks in AWS,
each with their own state file
```

The `.tf` files never change between environments. The `tfvars` file is the
only thing that differs. This is the `tfvars` approach to multi-environment —
simpler than Terraform Workspaces and easier to reason about.

---

## Dev vs Prod Differences

| Setting | Dev | Prod |
|---|---|---|
| `az_count` | 1 | 2 |
| `enable_nat_gateway` | false | true |
| `log_retention_days` | 7 | 90 |
| `prevent_table_destroy` | false | true |
| `vpc_cidr` | 10.0.0.0/16 | 10.1.0.0/16 |
| Lambda memory | 256 MB | 512 MB |

---

## New Concepts in This Project

### 1. Partial backend configuration

Backend blocks can't use variable interpolation — this is a hard Terraform
limitation. You can't write:

```hcl
# This does NOT work
backend "s3" {
  key = "07-multi-env/${var.environment}/terraform.tfstate"  # ❌
}
```

The solution is to omit the `key` from `backend.tf` and pass it at init time:

```bash
terraform init -backend-config="key=07-multi-env/dev/terraform.tfstate"
```

Each environment gets its own isolated state file path in the same bucket.

### 2. Switching environments requires re-init

Every time you switch from dev to prod (or back), you must run `terraform init`
with the new backend key. Use `-reconfigure` to avoid the interactive prompt:

```bash
# Switch to prod
terraform init -reconfigure \
  -backend-config="key=07-multi-env/prod/terraform.tfstate"

terraform apply -var-file=environments/prod.tfvars
```

### 3. `prevent_destroy` can't be dynamic — and the workaround

Terraform's `lifecycle` block does not support variable expressions:

```hcl
# This does NOT work
lifecycle {
  prevent_destroy = var.prevent_table_destroy  # ❌ — lifecycle args must be literal
}
```

The workaround is two resource blocks — one protected, one not — toggled
by `count`:

```hcl
resource "aws_dynamodb_table" "products" {
  count = var.prevent_table_destroy ? 0 : 1
  lifecycle { prevent_destroy = false }
}

resource "aws_dynamodb_table" "products_protected" {
  count = var.prevent_table_destroy ? 1 : 0
  lifecycle { prevent_destroy = true }
}
```

A `locals` block then unifies the two into a single name so the rest of
the config doesn't need to know which block was used:

```hcl
locals {
  dynamodb_table_name = var.prevent_table_destroy
    ? aws_dynamodb_table.products_protected[0].name
    : aws_dynamodb_table.products[0].name
}
```

### 4. Different VPC CIDRs per environment

Dev uses `10.0.0.0/16`, prod uses `10.1.0.0/16`. This isn't strictly
necessary when environments are in different AWS accounts, but it's good
practice — it allows VPC peering between environments without CIDR conflicts
if you ever need it (e.g. a data migration path from prod to dev).

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder. Leave `key` omitted — that's intentional.

---

### Deploy Dev

```bash
cd projects/07-multi-env

# Init with dev state key
terraform init \
  -backend-config="key=07-multi-env/dev/terraform.tfstate"

# Plan with dev vars
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
```

Check the outputs:
```bash
terraform output environment   # "dev"
terraform output api_base_url
```

Test it:
```bash
BASE=$(terraform output -raw api_base_url)
curl $BASE/
curl -X POST $BASE/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Dev Widget", "price": 1.00}'
curl $BASE/products
```

---

### Deploy Prod (in the same directory)

```bash
# Re-init with prod state key — -reconfigure skips the interactive prompt
terraform init -reconfigure \
  -backend-config="key=07-multi-env/prod/terraform.tfstate"

# Plan — notice the resource names all change to include "prod"
terraform plan -var-file=environments/prod.tfvars

# Apply
terraform apply -var-file=environments/prod.tfvars
```

```bash
terraform output environment   # "prod"
terraform output api_base_url  # different URL from dev
```

Both stacks are now live simultaneously. Go to the AWS Console and verify:
- Two VPCs: `tf-learning-dev-vpc` and `tf-learning-prod-vpc`
- Two Lambda functions: `tf-learning-api-dev` and `tf-learning-api-prod`
- Two DynamoDB tables: `tf-learning-products-dev` and `tf-learning-products-prod`
- Two separate state files in your S3 bucket under `07-multi-env/dev/` and `07-multi-env/prod/`

---

### Step 3 — Verify state isolation
```bash
# Check which state you're currently pointing at
terraform state list   # shows prod resources

# Switch back to dev state
terraform init -reconfigure \
  -backend-config="key=07-multi-env/dev/terraform.tfstate"

terraform state list   # shows dev resources — completely separate
```

---

### Step 4 — Try to destroy prod's table
```bash
# Make sure you're pointing at prod
terraform init -reconfigure \
  -backend-config="key=07-multi-env/prod/terraform.tfstate"

terraform destroy -var-file=environments/prod.tfvars
```

Terraform will error before touching the DynamoDB table:
```
│ Error: Instance cannot be destroyed
│ Resource aws_dynamodb_table.products_protected[0] has lifecycle.prevent_destroy
│ set, but the plan calls for this resource to be destroyed.
```

Everything else in the plan would proceed, but `prevent_destroy = true` acts
as a hard stop for that specific resource. Switch to dev and destroy freely:

```bash
terraform init -reconfigure \
  -backend-config="key=07-multi-env/dev/terraform.tfstate"

terraform destroy -var-file=environments/dev.tfvars  # works fine
```

---

### Step 5 — Destroy prod (you'll need to remove prevent_destroy first)

To actually tear down prod for this learning exercise:

1. In `main.tf`, temporarily change `prevent_table_destroy` default to `false`
   OR set it in prod.tfvars
2. Run `terraform apply -var-file=environments/prod.tfvars` to update the
   lifecycle (this recreates the table resource under the unprotected block)
3. Run `terraform destroy -var-file=environments/prod.tfvars`

In a real project you'd never remove `prevent_destroy` from prod. You'd
delete the table manually in the console first, then `terraform destroy`.

---

## tfvars vs Workspaces — When to Use Which

| | tfvars | Workspaces |
|---|---|---|
| State isolation | Yes — separate keys | Yes — separate state files |
| Config differences | Full — anything in tfvars | Limited — only via `terraform.workspace` |
| Visibility | Explicit files in repo | Implicit workspace name |
| Switching | `terraform init -reconfigure` | `terraform workspace select` |
| Best for | Different config per env | Same config, just separate state |
| Recommended | ✅ Most teams use this | Only for simple state isolation |

The `tfvars` approach wins in almost every real-world case because you can
see exactly what differs between environments just by diffing the two files.
Workspaces hide the differences inside a single `terraform.workspace` variable.

---

## What You've Built Across This Learning Path

```
modules/
  vpc/           — reusable VPC with public/private subnets, NAT GW toggle
  lambda/        — reusable Lambda with IAM, VPC config, optional policies
  api_gateway/   — reusable HTTP API with routes, CORS, access logging

projects/
  01-remote-state/    — S3 backend + DynamoDB lock setup
  02-flat-vpc/        — VPC topology without modules
  03-vpc-module/      — VPC refactored into a module
  04-lambda-module/   — Lambda module with VPC attachment
  05-api-gateway-module/ — API Gateway module with for_each routes
  06-serverless-api/  — Full app: VPC + Lambda + API GW + DynamoDB
  07-multi-env/       — Same app deployed to dev and prod via tfvars
```

You now have a production-shaped Terraform codebase with reusable modules,
remote state, and multi-environment deployments. The natural next steps from
here are CI/CD integration (GitHub Actions running plan on PR, apply on merge),
adding a staging environment, and exploring Terragrunt for DRYer root module
configuration across many environments.
