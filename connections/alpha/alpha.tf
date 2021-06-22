// Outgoing connection - standard BGP enabled connection

resource "azurerm_vpn_site" "alpha" {
  name                = "alpha-site"
  resource_group_name = data.terraform_remote_state.vwan.outputs.resource_group.name
  location            = data.terraform_remote_state.vwan.outputs.resource_group.location
  virtual_wan_id      = data.terraform_remote_state.vwan.outputs.virtual_wan.id

  device_model  = "VNETGW"
  device_vendor = "Azure"
  address_cidrs = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network.address_space

  link {
    name          = "link1"
    ip_address    = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.ip_address
    speed_in_mbps = 100

    /*
    bgp {
      asn             = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.asn
      peering_address = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.bgp_peering_address
    }
    */
  }
}

resource "azurerm_vpn_gateway_connection" "alpha" {
  name               = "alpha-connection"
  vpn_gateway_id     = data.terraform_remote_state.vwan.outputs.vpn_gateway.id
  remote_vpn_site_id = azurerm_vpn_site.alpha.id

  vpn_link {
    name             = "link1"
    vpn_site_link_id = azurerm_vpn_site.alpha.link[0].id
    bgp_enabled      = false
    shared_key       = md5(data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.id) // Just a string - md5 gives a nice predictable one.
  }
}


//==========================================================================================

// Return connection. Not needed if connecting to a real on prem VPN device.

resource "azurerm_virtual_network_gateway_connection" "alpha-lng0" {
  name                = "alpha-to-hub-vpngw-lng0"
  location            = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.location
  resource_group_name = data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = data.terraform_remote_state.sites.outputs.site["alpha"].virtual_network_gateway.id
  local_network_gateway_id   = data.terraform_remote_state.vwan.outputs.local_network_gateways[0].id
  enable_bgp                 = false
  shared_key                 = md5(data.terraform_remote_state.sites.outputs.site["alpha"].resource_group.id) // Just a string - md5 gives a nice predictable one.
}

