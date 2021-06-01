variable "name" {
  description = "Used for site, VM, virtual network etc."
  type        = string
}

variable "address_space" {
  description = "Virtual network address space. Expected netmask is /24 as subnets are derived."
  type        = string
  default     = "10.0.0.0/24"

  validation {
    condition     = tonumber(split("/", var.address_space)[1]) == 24
    error_message = "The subnet mask should be 24 bits for this module."
  }
}

variable "asn" {
  description = "Autonomous System Number (ASN) for BGP. See https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview#faq."
  type        = number
  default     = 65521
}



//===============================================================

variable "location" {
  description = "Azure region."
  type        = string
  default     = "West Europe"
}

variable "tags" {
  description = "Object of resource tags."
  type        = map(string)
  default     = {}
}

variable "admin_username" {
  description = "Admin username."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key_file" {
  description = "SSH public key file used for the adminuser."
  type        = string
  default     = "~/.ssh/id_rsa-pub"
}
