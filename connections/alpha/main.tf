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

resource "azurerm_vpn_site" "alpha" {
  name                = "alpha-site"
  resource_group_name = data.terraform_remote_state.vwan.outputs.resource_group.name
  location            = data.terraform_remote_state.vwan.outputs.resource_group.location
  virtual_wan_id      = data.terraform_remote_state.vwan.outputs.virtual_wan.id

  device_model  = "VNETGW"
  device_vendor = "Azure"

  link {
    name          = "link1"
    ip_address    = data.terraform_remote_state.sites.outputs.site["alpha"].ip_address
    speed_in_mbps = 100

    bgp {
      asn             = data.terraform_remote_state.sites.outputs.site["alpha"].asn
      peering_address = data.terraform_remote_state.sites.outputs.site["alpha"].bgp_peering_address
    }
  }
}

resource "azurerm_vpn_gateway_connection" "alpha" {
  name               = "alpha-connection"
  vpn_gateway_id     = data.terraform_remote_state.vwan.outputs.vpn_gateway.id
  remote_vpn_site_id = azurerm_vpn_site.alpha.id

  vpn_link {
    name             = "link1"
    vpn_site_link_id = azurerm_vpn_site.alpha.link[0].id
    bgp_enabled      = true
  }

  /*
  vpn_link {
    name             = "link2"
    vpn_site_link_id = azurerm_vpn_site.example.vpn_site_link[1].id
    bgp_enabled      = true
  }
  */
}
