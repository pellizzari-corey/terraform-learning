# =============================================================================
# modules/api_gateway/variables.tf
# =============================================================================

variable "name" {
  description = "Name of the HTTP API. Used for the API Gateway name and log group."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,128}$", var.name))
    error_message = "name must be alphanumeric with hyphens/underscores, max 128 chars."
  }
}

variable "description" {
  description = "Human-readable description of the API."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Routes
#
# A map where each KEY is a route key string ("METHOD /path") and each VALUE
# is an object with the Lambda details needed to wire the integration.
#
# Example:
#   routes = {
#     "GET /hello"      = { invoke_arn = module.lambda_hello.invoke_arn,  function_name = module.lambda_hello.function_name }
#     "POST /items"     = { invoke_arn = module.lambda_items.invoke_arn,  function_name = module.lambda_items.function_name }
#     "ANY /{proxy+}"   = { invoke_arn = module.lambda_catch.invoke_arn,  function_name = module.lambda_catch.function_name }
#   }
#
# Note: invoke_arn and function_name come from the lambda module's outputs.
# -----------------------------------------------------------------------------
variable "routes" {
  description = "Map of route key to Lambda integration details. Route key format: 'METHOD /path' (e.g. 'GET /hello', 'ANY /{proxy+}')."
  type = map(object({
    invoke_arn    = string
    function_name = string
  }))

  validation {
    condition = alltrue([
      for k in keys(var.routes) :
      can(regex("^(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS|ANY) /", k))
    ])
    error_message = "Each route key must start with an HTTP method followed by a path (e.g. 'GET /hello')."
  }
}

# -----------------------------------------------------------------------------
# CORS
# -----------------------------------------------------------------------------
variable "cors_configuration" {
  description = <<-EOT
    Optional CORS configuration. When null, no CORS headers are added.
    For a public API consumed by a browser frontend, set this to allow
    your frontend origin.
    Example:
      cors_configuration = {
        allow_origins = ["https://myapp.com"]
        allow_methods = ["GET", "POST", "OPTIONS"]
        allow_headers = ["Content-Type", "Authorization"]
        max_age       = 300
      }
  EOT
  type = object({
    allow_origins = list(string)
    allow_methods = list(string)
    allow_headers = list(string)
    max_age       = number
  })
  default = null
}

# -----------------------------------------------------------------------------
# Observability
# -----------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Retention period for API Gateway access logs in CloudWatch."
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a value supported by CloudWatch Logs."
  }
}
