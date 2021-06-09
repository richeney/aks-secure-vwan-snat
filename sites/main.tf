resource "azurerm_resource_group" "commify" {
  name     = "commify"
  location = var.location
}

module "site" {
  source         = "./site"
  for_each       = { for site in var.sites : site.name => site }
  name           = "commify-${each.value.name}"
  address_space  = each.value.address_space
  asn            = each.value.asn
  admin_username = var.admin_username
}

/*
resource "azurerm_virtual_wan" "vwan" {
  name                = "commify-vwan"
  resource_group_name = azurerm_resource_group.commify.name
  location            = var.location
}

resource "azurerm_virtual_hub" "vwan" {
  name                = "commify-vwan-hub"
  resource_group_name = azurerm_resource_group.commify.name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = "192.168.0.0/24"
}

resource "azurerm_vpn_gateway" "vwan" {
  name                = "commify-vwan-hub-vpngw"
  location            = var.location
  resource_group_name = azurerm_resource_group.commify.name
  virtual_hub_id      = azurerm_virtual_hub.vwan.id
}
*/
