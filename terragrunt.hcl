# Root terragrunt.hcl — Keystone Infra-Live
# Reads account.hcl / env.hcl / region.hcl from the directory hierarchy
# and auto-configures S3 backend, provider, and assume_role.
#
# Directory layout:
#   terragrunt.hcl           <- this file
#   {team}/account.hcl       <- account_id, account_name
#   {team}/{env}/env.hcl     <- environment
#   {team}/{env}/{region}/region.hcl <- aws_region
#   {team}/{env}/{region}/{module}/{resource}/terragrunt.hcl <- module

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  account_id   = local.account_vars.locals.account_id
  account_name = local.account_vars.locals.account_name
  environment  = local.env_vars.locals.environment
  aws_region   = local.region_vars.locals.aws_region
}

# S3 backend — one state bucket per AWS account
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "keystone-tfstate-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    use_lockfile    = true
  }
}

# AWS provider - credentials are provided by OIDC in the workflow
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = {
      ManagedBy   = "terragrunt"
      Platform    = "keystone"
      Environment = "${local.environment}"
      Account     = "${local.account_name}"
      Repository  = "Obulreddy58/test-infra"
    }
  }
}
EOF
}
