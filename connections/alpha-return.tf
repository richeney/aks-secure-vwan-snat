resource "azurerm_virtual_network_gateway_connection" "alpha-lng0" {
  name                = "alpha-to-hub-vpngw-lng0"
  location            = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.location
  resource_group_name = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.id
  local_network_gateway_id   = data.terraform_remote_state.vwan.outputs.local_network_gateways[0].id
  enable_bgp                 = true
}

/*
resource "azurerm_virtual_network_gateway_connection" "alpha-lng1" {
  name                = "alpha-to-hub-vpngw-lng1"
  location            = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.location
  resource_group_name = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.id
  local_network_gateway_id   = data.terraform_remote_state.vwan.outputs.local_network_gateways[1].id
  enable_bgp                 = true
}
*/