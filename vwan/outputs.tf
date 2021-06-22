output "resource_group" {
  value = azurerm_resource_group.vwan
}

output "virtual_wan" {
  value = azurerm_virtual_wan.vwan
}

output "vpn_gateway" {
  value = azurerm_vpn_gateway.vwan
}

output "local_network_gateways" {
  value = [
    azurerm_local_network_gateway.lng-a,
    azurerm_local_network_gateway.lng-b
  ]
}



