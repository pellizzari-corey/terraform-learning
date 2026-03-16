# Project 1.1 — Provider & Remote State Setup

## What you'll learn
- How to configure the AWS provider in Terraform
- Why remote state matters and how S3 + DynamoDB provide it
- The difference between `bootstrap` (one-time setup) and a normal project
- Core Terraform CLI workflow: `init` → `plan` → `apply` → `destroy`
- How `outputs`, `variables`, and `terraform.tfvars` work together

---

## Project Structure

```
01-remote-state/
├── bootstrap/          ← Run ONCE to create S3 + DynamoDB
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── main.tf             ← The actual project (uses the remote backend)
├── variables.tf
├── outputs.tf
├── backend.tf          ← Wires this project to the remote state bucket
└── terraform.tfvars    ← Your local variable values
```

---

## Step-by-Step Walkthrough

### Prerequisites
- Terraform >= 1.6 installed (`terraform -version`)
- AWS CLI configured (`aws sts get-caller-identity` should return your account)
- An IAM user/role with permissions for: S3, DynamoDB, SSM

---

### Step 1 — Run the Bootstrap (one time only)

The bootstrap creates the S3 bucket and DynamoDB table that will store state
for this and all future projects. It runs with *local* state intentionally —
you can't store state remotely before the remote infrastructure exists.

```bash
cd projects/01-remote-state/bootstrap

terraform init
terraform plan
terraform apply
```

After apply, note the outputs:
```bash
terraform output
# or for a specific value:
terraform output state_bucket_name
```

---

### Step 2 — Update backend.tf

Open `projects/01-remote-state/backend.tf` and replace the placeholder:
```hcl
bucket = "REPLACE_WITH_state_bucket_name_output"
```
with the actual bucket name from Step 1.

---

### Step 3 — Initialize the Main Project

```bash
cd projects/01-remote-state   # (go up one level from bootstrap)

terraform init
```

`init` does three things here:
1. Downloads the AWS provider plugin
2. Connects to the S3 backend
3. Creates the DynamoDB lock entry

You should see: `Successfully configured the backend "s3"`

---

### Step 4 — Plan

```bash
terraform plan
```

Plan shows you exactly what Terraform *would* do without making any changes.
Get comfortable reading its output — it's your best friend for reviewing
changes before they hit real infrastructure.

Key symbols:
- `+` resource will be **created**
- `-` resource will be **destroyed**
- `~` resource will be **updated in-place**
- `-/+` resource will be **destroyed and recreated**

---

### Step 5 — Apply

```bash
terraform apply
```

Type `yes` when prompted. After apply:

1. Go to AWS Console → S3 → your bucket
   - You should see `01-remote-state/terraform.tfstate`
2. Go to AWS Console → Systems Manager → Parameter Store
   - You should see `/tf-learning/hello`

---

### Step 6 — Inspect State

```bash
# List all resources tracked in state
terraform state list

# Show the full state for a specific resource
terraform state show aws_ssm_parameter.hello
```

This is how Terraform knows what exists — it maps your config to real resource
IDs stored in the `.tfstate` file (now living safely in S3).

---

### Step 7 — Make a Change

Open `main.tf` and change the SSM parameter name from `/tf-learning/hello`
to `/tf-learning/hello-v2`. Run `plan` again:

```bash
terraform plan
```

Notice the plan shows `-/+` — it will *destroy* the old parameter and *create*
a new one (because the `name` field is immutable in SSM). This is a key
Terraform concept: some field changes require replacement, not in-place update.

Revert the change before continuing.

---

### Step 8 — Destroy

```bash
terraform destroy
```

This removes the SSM parameter. The S3 bucket and DynamoDB table from the
bootstrap are left intact — you'll reuse them for every future project.

> ⚠️ Do NOT run `terraform destroy` inside the `bootstrap/` directory unless
> you want to delete your state infrastructure (which would orphan all future
> project states).

---

## Key Concepts Recap

| Concept | What it does |
|---|---|
| `provider` block | Tells Terraform which cloud + region to talk to |
| `backend "s3"` | Stores state remotely instead of locally |
| DynamoDB lock | Prevents two `apply` runs from corrupting state simultaneously |
| `terraform.tfvars` | Auto-loaded variable values (keep secrets out of here) |
| `outputs` | Expose values from a project (used heavily when modules call each other) |
| `lifecycle` block | Controls when Terraform ignores changes or prevents destroys |

---

## CDK Parallel

If you're coming from CDK, here's how this maps:

| CDK | Terraform |
|---|---|
| `cdk bootstrap` | `bootstrap/` directory in this project |
| CDK toolkit stack (S3 + ECR) | S3 bucket + DynamoDB table |
| `cdk.out/` synth artifacts | `.terraform/` directory |
| `cdk deploy` | `terraform apply` |
| CloudFormation stack outputs | `output` blocks |

---

## Next Up → Project 1.2: Your First VPC (flat)

Now that remote state is wired up, Project 1.2 will create a full VPC —
public/private subnets, IGW, route tables, and security groups — as flat
`.tf` files before we refactor it into a reusable module in Phase 2.
