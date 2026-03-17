# Project 2.2 — Lambda Module

## What you'll learn
- `archive_file` data source — zip local code at plan time automatically
- `dynamic` blocks — conditionally include a config block without duplication
- `count = var.x != null ? 1 : 0` — optional resource creation
- `jsonencode()` — building IAM policy JSON inline in HCL
- Module chaining — wiring one module's outputs directly into another's inputs
- The difference between VPC and non-VPC Lambda networking

---

## Architecture

```
                    ┌─────────────────────────────────┐
                    │             VPC                  │
  Internet          │  ┌──────────────────────────┐   │
     │              │  │  Private Subnet (AZ-a)   │   │
     │              │  │  ┌────────────────────┐  │   │
     ▼              │  │  │  lambda_vpc        │  │   │
  lambda_public     │  │  │  (SSM read policy) │  │   │
  (no VPC)          │  │  └────────────────────┘  │   │
                    │  └──────────────────────────┘   │
                    │           NAT GW ──► Internet    │
                    └─────────────────────────────────┘
```

Two Lambda functions — one outside the VPC (simpler, no NAT cost), one inside private subnets (can reach VPC-private resources like RDS).

---

## New Concepts in This Project

### 1. `archive_file` — automatic zipping at plan time

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/.terraform/lambda_package.zip"
}
```

`path.module` always resolves to the directory of the current `.tf` file.
This data source runs during plan, zips your `src/` folder, and writes the
zip to `.terraform/`. You never touch a zip file manually.

**Why `source_code_hash` matters:**
```hcl
source_code_hash = data.archive_file.lambda_zip.output_base64sha256
```
Without this, Terraform only redeploys Lambda if the zip file *path* changes.
With it, Terraform redeploys whenever the *contents* change. Always include it.

---

### 2. `dynamic` blocks — conditional config blocks

Regular variables can be `null` to skip a value. But sometimes you need to
conditionally include an entire *block* (like `vpc_config`). That's what
`dynamic` does:

```hcl
# Instead of this (doesn't work — you can't set a block to null):
vpc_config = var.vpc_config  # ❌

# Use this:
dynamic "vpc_config" {
  for_each = var.vpc_config != null ? [var.vpc_config] : []
  content {
    subnet_ids         = vpc_config.value.subnet_ids
    security_group_ids = vpc_config.value.security_group_ids
  }
}
```

`for_each = [var.vpc_config]` — list with one item = block is included once.
`for_each = []` — empty list = block is omitted entirely.

The same pattern is used for `environment {}` — only included when env vars
are provided.

---

### 3. Module chaining — outputs flow directly into inputs

```hcl
module "vpc" {
  source = "../../modules/vpc"
  ...
}

module "lambda_vpc" {
  source = "../../modules/lambda"

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids  # ← vpc output
    security_group_ids = [module.vpc.sg_lambda_id]      # ← vpc output
  }
}
```

Terraform builds a dependency graph from these references:
`module.vpc` must be fully applied before `module.lambda_vpc` can plan its
resources. You don't declare this explicitly — Terraform infers it.

---

### 4. `jsonencode()` — IAM policy inline

```hcl
policy_json = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect   = "Allow"
    Action   = ["ssm:GetParameter"]
    Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
  }]
})
```

`jsonencode()` converts HCL objects/maps to JSON strings. This keeps IAM
policies readable in HCL rather than escaping raw JSON strings. Variable
interpolation (`${var.aws_region}`) works inside it normally.

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder with your state bucket name.

### Step 2 — Init & Plan
```bash
cd projects/04-lambda-module
terraform init
terraform plan
```

The plan creates resources across two modules. Notice the address structure:
```
module.vpc.aws_vpc.main
module.lambda_public.aws_lambda_function.this
module.lambda_public.aws_iam_role.lambda
module.lambda_vpc.aws_lambda_function.this
module.lambda_vpc.aws_iam_role_policy.extra[0]   ← [0] because count = 1
module.lambda_vpc.aws_iam_role_policy_attachment.vpc_access[0]
```

### Step 3 — Apply
```bash
terraform apply
```

### Step 4 — Test the functions in the AWS console
1. Go to Lambda → Functions
2. Click `tf-learning-public-dev` → Test tab
3. Create a test event (the default hello-world JSON is fine)
4. Click Test — you should see a 200 response with the greeting
5. Repeat for `tf-learning-vpc-dev`

### Step 5 — Check CloudWatch logs
```bash
# Get the log group names
terraform output lambda_public_log_group
terraform output lambda_vpc_log_group
```
Go to CloudWatch → Log Groups → find the group → look for the log stream
from your test invocation.

### Step 6 — Update the handler code and redeploy
Open `src/handler.py` and change the greeting message. Then:
```bash
terraform plan
```

Because `source_code_hash` is wired to the zip contents, Terraform will detect
the change and show `module.lambda_public.aws_lambda_function.this` as `~`
(update in place). Apply it and test again to confirm the new code runs.

### Step 7 — Inspect state
```bash
terraform state list
terraform state show 'module.lambda_vpc.aws_lambda_function.this'
terraform state show 'module.lambda_vpc.aws_iam_role.lambda'
```

### Step 8 — Destroy
```bash
terraform destroy
```

---

## Lambda Module: Input/Output Contract

### Key Inputs
| Variable | Required | Purpose |
|---|---|---|
| `function_name` | yes | Function name (include env suffix at call site) |
| `handler` | yes | `file.method` entrypoint |
| `filename` | one of | Local zip path (use with `source_code_hash`) |
| `s3_bucket` + `s3_key` | one of | S3 deployment package |
| `runtime` | no | Default: `python3.12` |
| `vpc_config` | no | `null` = public network, object = VPC-attached |
| `policy_json` | no | Additional IAM permissions as JSON string |
| `environment_variables` | no | Runtime env vars as `map(string)` |

### Key Outputs
| Output | Used by |
|---|---|
| `function_arn` | Permissions, event source mappings |
| `invoke_arn` | API Gateway integration (next project!) |
| `role_name` | Attaching additional managed policies |
| `log_group_name` | CloudWatch dashboards, alarms |

---

## Next Up → Project 2.3: `api_gateway` Module

Wire an HTTP API Gateway to `module.lambda_vpc.invoke_arn` to create a
publicly accessible REST endpoint backed by a Lambda running in private subnets.
