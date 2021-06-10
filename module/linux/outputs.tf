output "fqdn" {
  value = var.dns_label != null ? azurerm_public_ip.linux[var.name].fqdn : null
}

output "public_ip_address" {
  value = var.dns_label != null ? azurerm_public_ip.linux[var.name].ip_address : null
}

output "ssh_command" {
  value = var.dns_label != null ? "ssh ${var.admin_username}@${azurerm_public_ip.linux[var.name].fqdn}" : null
}
