resource "azurerm_resource_group" "vwan" {
  name     = "${var.name}-vwan"
  location = var.location
}

resource "azurerm_virtual_wan" "vwan" {
  name                = "${var.name}-vwan"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location

  type                           = "Standard"
  allow_branch_to_branch_traffic = false
}

resource "azurerm_virtual_hub" "vwan" {
  name                = "${var.name}-hub"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location

  sku            = "Standard"
  address_prefix = var.address_prefix
  virtual_wan_id = azurerm_virtual_wan.vwan.id
}

resource "azurerm_vpn_gateway" "vwan" {
  name                = "${var.name}-vpngw"
  location            = azurerm_resource_group.vwan.location
  resource_group_name = azurerm_resource_group.vwan.name
  virtual_hub_id      = azurerm_virtual_hub.vwan.id
}

resource "azurerm_virtual_hub_connection" "aks" {
  name                      = "aks"
  virtual_hub_id            = azurerm_virtual_hub.vwan.id
  remote_virtual_network_id = var.aks_virtual_network_id
  depends_on                = [azurerm_vpn_gateway.vwan]
}
