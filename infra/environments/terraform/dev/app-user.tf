locals {
  deployment_principal_id = try(local.config.deployment_principal_id, "")
  create_app_user         = local.deployment_principal_id != ""
}

data "powerplatform_data_records" "role_system_admin" {
  count             = local.create_app_user ? 1 : 0
  environment_id    = powerplatform_environment.this.id
  entity_collection = "roles"
  filter            = "name eq 'System Administrator' and _businessunitid_value eq ${data.powerplatform_data_records.root_business_unit.rows[0]["businessunitid"]}"
  select            = ["name", "roleid"]
}

resource "powerplatform_data_record" "app_user" {
  count               = local.create_app_user ? 1 : 0
  environment_id      = powerplatform_environment.this.id
  table_logical_name  = "systemuser"
  columns = {
    fullname      = "CD deployment principal"
    applicationid = local.deployment_principal_id
    businessunitid = {
      table_logical_name = "businessunit"
      data_record_id     = data.powerplatform_data_records.root_business_unit.rows[0]["businessunitid"]
    }
    systemuserroles_association = toset([{
      table_logical_name = "role"
      data_record_id     = data.powerplatform_data_records.role_system_admin[0].rows[0]["roleid"]
    }])
  }
}
