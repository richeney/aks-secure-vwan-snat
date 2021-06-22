output "virtual_machine_name" {
  value = var.name
}

output "siteinfo" {
  value = {
    name = var.name,
    resource_group = {
      name     = azurerm_resource_group.site.name
      id       = azurerm_resource_group.site.id
      location = azurerm_resource_group.site.location
    },
    virtual_network_gateway = {
      name                = azurerm_virtual_network_gateway.vpngw.name
      id                  = azurerm_virtual_network_gateway.vpngw.id
      asn                 = var.asn
      ip_address          = azurerm_public_ip.vpngw.ip_address
      bgp_peering_address = azurerm_virtual_network_gateway.vpngw.bgp_settings[0].peering_address
    },
    virtual_network = {
      name          = azurerm_virtual_network.site.name
      id            = azurerm_virtual_network.site.id
      address_space = azurerm_virtual_network.site.address_space
    }
  }
}
