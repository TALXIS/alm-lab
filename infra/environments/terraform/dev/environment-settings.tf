locals {
  audit_and_logs_config = try(local.config.environment_settings.audit_and_logs, {})
  audit_and_logs = {
    plugin_trace_log_setting = try(local.audit_and_logs_config.plugin_trace_log_setting, "Exception")
    audit_settings = {
      is_audit_enabled             = try(local.audit_and_logs_config.audit_settings.is_audit_enabled, true)
      is_read_audit_enabled        = try(local.audit_and_logs_config.audit_settings.is_read_audit_enabled, true)
      is_user_access_audit_enabled = try(local.audit_and_logs_config.audit_settings.is_user_access_audit_enabled, true)
      log_retention_period_in_days = try(local.audit_and_logs_config.audit_settings.log_retention_period_in_days, 31)
    }
  }
}

resource "powerplatform_environment_settings" "this" {
  environment_id = powerplatform_environment.this.id
  audit_and_logs = local.audit_and_logs
}
