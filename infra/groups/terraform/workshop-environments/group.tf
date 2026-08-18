locals {
  display_name     = "Warehouse Lab Environments"
  description      = "Groups the Dev/Test Dataverse sandboxes created by CP04 for the Power Platform ALM workshop."
  rule_set_enabled = false
}

resource "powerplatform_environment_group" "this" {
  display_name = local.display_name
  description  = local.description
}

resource "powerplatform_environment_group_rule_set" "this" {
  count = local.rule_set_enabled ? 1 : 0

  environment_group_id = powerplatform_environment_group.this.id

  rules = {
    sharing_controls = {
      share_mode      = "exclude sharing with security groups"
      share_max_limit = 10
    }
    usage_insights = {
      insights_enabled = true
    }
    solution_checker_enforcement = {
      solution_checker_mode = "warn"
      send_emails_enabled   = false
    }
    backup_retention = {
      period_in_days = 7
    }
  }
}

output "id" {
  value       = powerplatform_environment_group.this.id
  description = "Environment group id"
}
