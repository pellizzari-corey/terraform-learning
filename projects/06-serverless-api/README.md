# Project 3 — Full Serverless API

## What you'll learn
- Composing all three modules (vpc, lambda, api_gateway) in one root
- Managing application-level resources (DynamoDB) alongside compute modules
- Building IAM policies from live resource ARNs — no hardcoded strings
- Injecting Terraform resource names into Lambda via environment variables
- How the full request path flows: Internet → API GW → Lambda → DynamoDB
- The `curl_examples` output pattern for self-documenting deployments

---

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────────────┐
│  API Gateway (HTTP API v2)      │
│  GET  /                         │
│  GET  /products                 │
│  GET  /products/{id}            │
│  POST /products                 │
└────────────────┬────────────────┘
                 │ Lambda Proxy
                 ▼
┌─────────────────────────────────┐
│  VPC (10.0.0.0/16)             │
│  ┌───────────────────────────┐  │
│  │  Private Subnet           │  │
│  │  Lambda (Python 3.12)     │  │
│  │  256 MB / 30s timeout     │  │
│  └────────────┬──────────────┘  │
│               │ NAT GW          │
└───────────────┼─────────────────┘
                │ AWS internal network
                ▼
┌─────────────────────────────────┐
│  DynamoDB                       │
│  tf-learning-products-dev       │
│  PAY_PER_REQUEST                │
└─────────────────────────────────┘
```

---

## Key Design Decisions

### Why is DynamoDB in the root module, not a child module?

The VPC and Lambda modules are *generic infrastructure* — they don't know
anything about products or this specific application. DynamoDB is
*application-specific* — it belongs to this project's root module.

A good rule of thumb: if you'd reuse the module across unrelated projects,
it belongs in `modules/`. If it's specific to this application's data model,
it belongs in the root.

### IAM policy uses live ARNs, not hardcoded strings

```hcl
# Bad — hardcoded, fragile, wrong environment if you copy/paste
Resource = "arn:aws:dynamodb:us-east-1:123456789:table/products"

# Good — Terraform resolves this at apply time from the actual resource
Resource = aws_dynamodb_table.products.arn
```

This means the policy is always correct regardless of environment, region,
or account. The Lambda can only access *this specific table*, not any table
in the account.

### Environment variables bridge Terraform and Lambda

```hcl
environment_variables = {
  PRODUCTS_TABLE = aws_dynamodb_table.products.name  # Terraform output → Lambda config
  STAGE          = var.environment
}
```

The Lambda never hardcodes the table name. Terraform injects it at deploy
time. This is the standard pattern for wiring infrastructure names into
application config — it also means changing `project_name` or `environment`
automatically propagates the new table name to the Lambda.

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder as usual.

### Step 2 — Init & Plan
```bash
cd projects/06-serverless-api
terraform init
terraform plan
```

Count the resources. You should see approximately **25 resources** across
four namespaces:
- `aws_dynamodb_table.products` — root module
- `module.vpc.*` — 15 resources
- `module.lambda.*` — 5 resources
- `module.api_gateway.*` — 10 resources

Notice that `module.lambda` has a dependency on `aws_dynamodb_table.products`
because `policy_json` references `aws_dynamodb_table.products.arn`. Terraform
infers this and will always create the table before the Lambda role policy.

### Step 3 — Apply
```bash
terraform apply
```

### Step 4 — Test with the generated curl commands
```bash
# Print the ready-to-run curl examples
terraform output curl_examples
```

Run through the full flow:
```bash
BASE=$(terraform output -raw api_base_url)

# 1. Health check
curl $BASE/

# 2. List products (empty table)
curl $BASE/products

# 3. Create a product — save the returned id
curl -X POST $BASE/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Widget Pro", "price": 29.99}'

# 4. Create another
curl -X POST $BASE/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Gadget Lite", "price": 9.99}'

# 5. List again — should now have two items
curl $BASE/products

# 6. Get a single product (replace ID with one from step 3)
curl $BASE/products/YOUR_PRODUCT_ID_HERE

# 7. Try a missing product
curl $BASE/products/does-not-exist
```

### Step 5 — Verify in DynamoDB console
Go to DynamoDB → Tables → `tf-learning-products-dev` → Explore items.
You should see the products you created via the API.

### Step 6 — Check both log groups
```bash
terraform output lambda_log_group
terraform output api_log_group
```

Open both in CloudWatch. The API GW log shows one structured JSON line per
request (method, route, status, latency). The Lambda log shows your Python
`print()` statements and any errors.

### Step 7 — Trigger a real error
```bash
# Send invalid JSON
curl -X POST $BASE/products \
  -H "Content-Type: application/json" \
  -d 'not-json'

# Send missing required field
curl -X POST $BASE/products \
  -H "Content-Type: application/json" \
  -d '{"price": 5.00}'
```

Check the Lambda log group to see how the errors surface. This is a
realistic debugging workflow — API GW access logs tell you *that* a request
failed, Lambda logs tell you *why*.

### Step 8 — Inspect the dependency graph
```bash
terraform graph | dot -Tsvg > graph.svg
```

If you have Graphviz installed (`brew install graphviz`), this generates
a visual of the full dependency graph. You'll see the edges from
`aws_dynamodb_table.products` flowing into `module.lambda` and the
chain of vpc → lambda → api_gateway module dependencies.

### Step 9 — Destroy
```bash
terraform destroy
```

Delete Lambda ENIs manually first if needed (see Project 2.2 / 2.3 notes).

---

## What's Different About This Project vs 2.3

| | Project 2.3 | Project 3 |
|---|---|---|
| Data store | None | DynamoDB |
| IAM policy | SSM read (example) | DynamoDB CRUD (real) |
| Lambda env vars | STAGE only | STAGE + PRODUCTS_TABLE |
| Handler logic | Static responses | Real reads/writes |
| Routes | 3 | 4 (added `GET /products/{id}`) |
| Root module resources | 0 | 1 (DynamoDB table) |

---

## Next Up → Phase 4: Multi-Environment (dev / prod)

Take this exact project and deploy it to two isolated environments using
separate `tfvars` files. You'll learn:
- `dev.tfvars` vs `prod.tfvars` — different table names, NAT GW toggle, retention periods
- How a single set of modules serves multiple environments safely
- State isolation per environment — each gets its own `.tfstate` key
