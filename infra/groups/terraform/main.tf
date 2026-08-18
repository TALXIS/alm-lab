terraform {
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.13"
}

provider "powerplatform" {
  use_cli = true
}

module "workshop_environments" {
  source = "./workshop-environments"
}

output "group_ids" {
  description = "Environment group IDs — paste into environments/*/config.yml (environment_group_id) and tenant/terraform variables"
  value = {
    workshop_environments = module.workshop_environments.id
  }
}
