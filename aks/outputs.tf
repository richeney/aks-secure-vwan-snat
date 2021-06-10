output "testvm_fqdn" {
  value = module.testvm.fqdn
}

output "testvm_public_ip_address" {
  value = module.testvm.public_ip_address
}

output "testvm_ssh_command" {
  value = module.testvm.ssh_command
}

output "aks_kubeconfig_command" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${azurerm_resource_group.aks.name}"
}
