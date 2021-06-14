locals {
  vpngw_public_ip_addresses = [
    tolist(azurerm_vpn_gateway.vwan.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1],
    tolist(azurerm_vpn_gateway.vwan.bgp_settings[0].instance_1_bgp_peering_address[0].tunnel_ips)[1]
  ]

  vpngw_bgp_peering_addresses = [
    tolist(azurerm_vpn_gateway.vwan.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0],
    tolist(azurerm_vpn_gateway.vwan.bgp_settings[0].instance_1_bgp_peering_address[0].default_ips)[0]
  ]

  asn = azurerm_vpn_gateway.vwan.bgp_settings[0].asn
}

resource "azurerm_local_network_gateway" "lng0" {
  name                = "${var.name}-return-connection-lng0"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location
  depends_on          = [azurerm_vpn_gateway.vwan]

  gateway_address = local.vpngw_public_ip_addresses[0]

  bgp_settings {
    asn                 = local.asn
    bgp_peering_address = local.vpngw_bgp_peering_addresses[0]
  }
}

resource "azurerm_local_network_gateway" "lng1" {
  name                = "${var.name}-return-connection-lng1"
  resource_group_name = azurerm_resource_group.vwan.name
  location            = azurerm_resource_group.vwan.location
  depends_on          = [azurerm_vpn_gateway.vwan]

  gateway_address = local.vpngw_public_ip_addresses[1]

  bgp_settings {
    asn                 = local.asn
    bgp_peering_address = local.vpngw_bgp_peering_addresses[1]
  }
}
