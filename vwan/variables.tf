variable "name" {
  description = "Name used to prefix resource names etc."
  type        = string
  default     = "example"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "address_prefix" {
  type    = string
  default = "172.20.0.0/24"
}

variable "aks_virtual_network_id" {
  description = "Resource ID for the virtual network used by the Azure Kubernetes Service cluster."
  type        = string
}
