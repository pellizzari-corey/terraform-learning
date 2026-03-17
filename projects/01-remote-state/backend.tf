# =============================================================================
# backend.tf — Remote state configuration
#
# This file is the TEMPLATE you'll copy into every future project.
# After running the bootstrap, replace the placeholder values below with
# the real outputs from: terraform output -json (in the bootstrap/ directory)
#
# IMPORTANT: The `key` must be unique per project so each project gets
# its own isolated state file within the shared bucket.
# =============================================================================

terraform {
  backend "s3" {
    # ---------------------------------------------------------------------------
    # Replace with your bootstrap outputs
    # ---------------------------------------------------------------------------
    bucket         = "REPLACE_WITH_state_bucket_name_output"
    region         = "us-east-1"                   # Must match bootstrap region
    dynamodb_table = "tf-learning-locks"

    # ---------------------------------------------------------------------------
    # Change this key for every new project — it's the path inside the bucket.
    # Convention: <project-name>/terraform.tfstate
    # ---------------------------------------------------------------------------
    key = "01-remote-state/terraform.tfstate"

    # Always encrypt state at rest
    encrypt = true
  }
}
