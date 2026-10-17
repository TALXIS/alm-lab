terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.13"
}

# Defaults to Azure CLI auth (the `az` session CP01/CP05 already established) —
# no client secret / OIDC variables needed for a local run.
provider "azuread" {}

variable "app_display_name" {
  description = "Display name for the deployment app registration."
  type        = string
  default     = "wm-deploy-TODO-RANDOM-ID" # mirrors CP05's "wm-deploy-$rid" naming
}

variable "github_repo" {
  description = "owner/repo of the attendee's fork, used in the federated credential subject."
  type        = string
  default     = "TODO-CHANGE-ME/alm-lab"
}

resource "azuread_application" "deploy" {
  display_name = var.app_display_name
}

resource "azuread_service_principal" "deploy" {
  client_id = azuread_application.deploy.client_id
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.deploy.id
  display_name   = "github-main"
  description    = "GitHub Actions OIDC trust for deployments from main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:ref:refs/heads/main"
}

output "client_id" {
  description = "Azure AD application (client) ID — paste into environments/test/config.yml as deployment_principal_id"
  value       = azuread_application.deploy.client_id
}

output "service_principal_object_id" {
  description = "Service principal object ID."
  value       = azuread_service_principal.deploy.object_id
}
