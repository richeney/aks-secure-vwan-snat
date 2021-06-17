terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.58.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "terraform_remote_state" "vwan" {
  backend = "local"

  config = {
    path = "../../vwan/terraform.tfstate"
  }
}

data "terraform_remote_state" "sites" {
  backend = "local"

  config = {
    path = "../../sites/terraform.tfstate"
  }
}