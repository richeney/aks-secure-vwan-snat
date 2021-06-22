output "testvm_fqdn" {
  value = module.testvm.fqdn
}

output "testvm_public_ip_address" {
  value = module.testvm.public_ip_address
}

output "testvm_ssh_command" {
  value = module.testvm.ssh_command
}

output "kubeconfig_command" {
  value = "az aks get-credentials --name ${azurerm_kubernetes_cluster.aks.name} --resource-group ${azurerm_resource_group.aks.name}"
}

output "virtual_network" {
  value = azurerm_virtual_network.aks
}

output "ubuntu_pod_commands" {
  value = <<-EOT
  kubectl exec --stdin --tty ubuntu -- /bin/bash
  apt-get update && apt-get install openssh-client -y
  exit
  
  kubectl cp ~/.ssh/id_rsa ubuntu:/id_rsa
  
  kubectl exec --stdin --tty ubuntu -- /bin/bash
  ssh -i id_rsa azureuser@<ip_address>
  echo $SSH_CLIENT | awk '{print $1}'
  exit

  exit
  EOT
}