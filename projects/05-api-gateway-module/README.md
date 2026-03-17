# Project 2.3 — API Gateway Module

## What you'll learn
- HTTP API Gateway v2 vs REST API v1 — when to use which
- `for_each` on a map variable — creating multiple resources from a map
- Why `for_each` beats `count` for resources with meaningful identities
- `aws_lambda_permission` — why it's needed and how to scope it correctly
- `payload_format_version` — how the event shape differs between v1.0 and v2.0
- Full three-module composition: vpc + lambda + api_gateway
- How to immediately test a live endpoint with `curl`

---

## Architecture

```
Internet
   │
   ▼
API Gateway (HTTP API v2)
   │  $default stage, auto-deploy
   │
   ├── GET  /hello  ──┐
   ├── GET  /items  ──┤──► Lambda (private subnet)
   └── POST /items  ──┘         │
                                ▼
                         CloudWatch Logs
```

API Gateway is fully managed — it lives outside your VPC. Your Lambda runs
in private subnets. The two connect over AWS's internal network via the
Lambda proxy integration.

---

## New Concepts in This Project

### 1. `for_each` on a map — vs `count`

`count` creates indexed copies: `resource[0]`, `resource[1]`.
`for_each` creates keyed copies: `resource["GET /hello"]`, `resource["POST /items"]`.

```hcl
# The routes variable is a map:
routes = {
  "GET /hello"  = { invoke_arn = "...", function_name = "..." }
  "POST /items" = { invoke_arn = "...", function_name = "..." }
}

# for_each iterates it:
resource "aws_apigatewayv2_route" "lambda" {
  for_each  = var.routes
  route_key = each.key    # "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"
}
```

**Why this matters:** if you used `count` and removed the first route,
everything would shift indexes and Terraform would destroy/recreate all routes.
With `for_each` and a map, removing `"GET /hello"` only deletes that one route.
State addresses are stable because they're keyed by the route string, not an index.

---

### 2. `aws_lambda_permission` — the invisible gotcha

API Gateway needs explicit permission to invoke Lambda. This is separate from
IAM — it's a **resource-based policy** on the Lambda function itself.

```hcl
resource "aws_lambda_permission" "api_gw" {
  for_each = var.routes

  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
```

Without this, your API returns **500** even though the integration looks
correct in the console. The `source_arn` scopes the permission to only this
specific API — better than allowing any API Gateway in the account.

---

### 3. `payload_format_version = "2.0"`

The event shape Lambda receives differs between versions:

```python
# v1.0 (REST API style)
method = event['httpMethod']          # "GET"
path   = event['path']                # "/hello"

# v2.0 (HTTP API style — what this module uses)
method = event['requestContext']['http']['method']   # "GET"
path   = event['requestContext']['http']['path']     # "/hello"
```

v2.0 also gives you a cleaner body (already decoded for JSON content types)
and a simpler response format. See `src/handler.py` for usage.

---

## Step-by-Step Walkthrough

### Step 1 — Update backend.tf
Replace the bucket placeholder as usual.

### Step 2 — Init & Plan
```bash
cd projects/05-api-gateway-module
terraform init
terraform plan
```

Check the plan for the three `for_each` resource groups:
```
module.api_gateway.aws_apigatewayv2_integration.lambda["GET /hello"]
module.api_gateway.aws_apigatewayv2_integration.lambda["GET /items"]
module.api_gateway.aws_apigatewayv2_integration.lambda["POST /items"]
module.api_gateway.aws_apigatewayv2_route.lambda["GET /hello"]
...
module.api_gateway.aws_lambda_permission.api_gw["GET /hello"]
...
```

### Step 3 — Apply
```bash
terraform apply
```

### Step 4 — Get the invoke URL and test immediately
```bash
# Get the ready-to-use endpoints
terraform output hello_endpoint
terraform output items_endpoint

# Or grab the base URL and build paths yourself
BASE=$(terraform output -raw invoke_url)

# Test all three routes
curl "$BASE/hello"
curl "$BASE/items"
curl -X POST "$BASE/items" \
  -H "Content-Type: application/json" \
  -d '{"name": "new-widget", "price": 9.99}'

# Test the 404 catch-all
curl "$BASE/nonexistent"
```

Expected responses:
```json
// GET /hello
{"message": "Hello from API Gateway + Lambda!", "stage": "dev"}

// GET /items
{"items": ["widget", "gadget", "thingamajig"], "stage": "dev"}

// POST /items
{"message": "Item created (not really - this is a demo)", "received": {"name": "new-widget", "price": 9.99}, "stage": "dev"}
```

### Step 5 — Check access logs
```bash
terraform output api_log_group
```
Go to CloudWatch → Log Groups → find the API GW log group.
Each request generates a structured log line with method, path, status, and latency.

### Step 6 — Add a new route without touching existing ones
In `main.tf`, add a new route to the `routes` map:
```hcl
"DELETE /items" = {
  invoke_arn    = module.lambda.invoke_arn
  function_name = module.lambda.function_name
}
```
Run `terraform plan`. Only three new resources are added:
- `aws_apigatewayv2_integration.lambda["DELETE /items"]`
- `aws_apigatewayv2_route.lambda["DELETE /items"]`
- `aws_lambda_permission.api_gw["DELETE /items"]`

All existing routes are untouched. This is `for_each` doing its job.
Revert before continuing.

### Step 7 — Destroy
```bash
terraform destroy
```

Remember to delete Lambda ENIs manually first if needed (see Project 2.2 notes).

---

## Module Input/Output Contract

### Key Inputs
| Variable | Required | Purpose |
|---|---|---|
| `name` | yes | API name and log group prefix |
| `routes` | yes | Map of route keys to Lambda ARN + name |
| `cors_configuration` | no | CORS headers config, null to disable |
| `log_retention_days` | no | Default: 14 days |

### Key Outputs
| Output | Used by |
|---|---|
| `invoke_url` | curl, frontend apps, integration tests |
| `api_id` | CloudWatch dashboards, WAF association |
| `execution_arn` | Scoping Lambda permissions |
| `log_group_name` | Alarms, dashboards |

---

## HTTP API (v2) vs REST API (v1) — Quick Reference

| Feature | HTTP API (v2) | REST API (v1) |
|---|---|---|
| Price | ~$1/million requests | ~$3.50/million requests |
| Lambda proxy | Built-in | Manual setup |
| CORS | Native support | Manual gateway responses |
| Usage plans / API keys | No | Yes |
| Request validation | No | Yes |
| WAF integration | No | Yes |
| JWT authorizers | Yes | No (use Lambda authorizer) |

**Rule of thumb:** start with HTTP API. Migrate to REST API only if you
need usage plans, API keys, or WAF.

---

## Next Up → Phase 3: Composing a Full Serverless App

Projects 2.1, 2.2, and 2.3 built three standalone modules. Phase 3 composes
all of them into a single production-shaped project, adds `terraform_remote_state`
for cross-project state sharing, and introduces multi-environment deployments
with `tfvars` files.
