terraform {
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.13"
}

provider "powerplatform" {
  use_cli = true
}

provider "azuread" {}

module "dev" {
  source = "./dev"
}

module "test" {
  source = "./test"
}
