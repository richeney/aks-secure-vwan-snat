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

data "terraform_remote_state" "aks" {
  backend = "local"

  config = {
    path = "../aks/terraform.tfstate"
  }
}
