terraform {
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.13"
}

# Reuses the pac/txc CLI session already established by CP01 — no service
# principal or client secret is available in this lab, so we ride on the CLI's
# cached credentials instead of a remote-CI/OIDC auth story.
provider "powerplatform" {
  use_cli = true
}

variable "routing_target_environment_group_id" {
  description = "Environment group new environments should be routed into by default."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000" # paste from groups/terraform output "group_ids"
}

variable "routing_target_security_group_id" {
  description = "Security group allowed to trigger environment routing."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000" # TODO-CHANGE-ME
}

# Tenant-wide settings are a singleton — one lab tenant, one settings object.
resource "powerplatform_tenant_settings" "this" {
  walk_me_opt_out                                       = false
  disable_newsletter_sendout                            = false
  disable_environment_creation_by_non_admin_users       = true
  disable_portals_creation_by_non_admin_users           = true
  disable_trial_environment_creation_by_non_admin_users = true
  disable_capacity_allocation_by_environment_admins     = true
  disable_support_tickets_visible_by_all_users          = false

  power_platform = {
    governance = {
      enable_default_environment_routing              = false
      environment_routing_all_makers                  = true
      environment_routing_target_environment_group_id = var.routing_target_environment_group_id
      environment_routing_target_security_group_id    = var.routing_target_security_group_id
    }
  }
}
