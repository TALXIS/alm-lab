data "powerplatform_data_records" "root_business_unit" {
  environment_id    = powerplatform_environment.this.id
  entity_collection = "businessunits"
  filter            = "parentbusinessunitid eq null"
  select            = ["name", "businessunitid"]
}

locals {
  security_teams = try(local.config.security_teams, [])
  team_role_pairs = flatten([
    for team in local.security_teams : [
      for role in team.roles : { key = "${team.name}-${role}", team_name = team.name, role_name = role }
    ]
  ])
  unique_roles = distinct([for pair in local.team_role_pairs : pair.role_name])
}

data "azuread_group" "teams" {
  for_each     = { for t in local.security_teams : t.name => t.aad_group_name }
  display_name = each.value
}

data "powerplatform_data_records" "security_roles" {
  for_each          = toset(local.unique_roles)
  environment_id    = powerplatform_environment.this.id
  entity_collection = "roles"
  filter            = "name eq '${each.value}' and _businessunitid_value eq ${data.powerplatform_data_records.root_business_unit.rows[0]["businessunitid"]}"
  select            = ["name", "roleid"]
}

resource "powerplatform_data_record" "security_teams" {
  for_each           = { for t in local.security_teams : t.name => t }
  environment_id     = powerplatform_environment.this.id
  table_logical_name = "team"
  columns = {
    name                         = each.value.name
    description                  = "${each.value.name} team - ${local.config.display_name}"
    teamtype                     = 2
    azureactivedirectoryobjectid = data.azuread_group.teams[each.key].object_id
    teamroles_association = toset([
      for role in each.value.roles : {
        table_logical_name = "role"
        data_record_id     = data.powerplatform_data_records.security_roles[role].rows[0]["roleid"]
      }
    ])
  }
}
