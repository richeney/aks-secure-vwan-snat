output "virtual_machine_name" {
  value = var.name
}

output "siteinfo" {
  value = {
    name                = var.name
    asn                 = var.asn
    ip_address          = azurerm_public_ip.vpngw.ip_address
    bgp_peering_address = azurerm_virtual_network_gateway.vpngw.bgp_settings[0].peering_address
  }
}
