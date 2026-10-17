locals {
  config = yamldecode(file("${path.module}/config.yml"))
  environment_group_id = (
    try(local.config.environment_group_id, "") != ""
    ? local.config.environment_group_id
    : "00000000-0000-0000-0000-000000000000"
  )
}

resource "powerplatform_environment" "this" {
  display_name         = local.config.display_name
  description          = local.config.description
  location             = local.config.location
  environment_type     = local.config.environment_type
  environment_group_id = local.environment_group_id

  dataverse = {
    language_code     = local.config.dataverse.language_code
    currency_code     = local.config.dataverse.currency_code
    domain            = local.config.dataverse.domain
    security_group_id = "00000000-0000-0000-0000-000000000000"
  }
}
