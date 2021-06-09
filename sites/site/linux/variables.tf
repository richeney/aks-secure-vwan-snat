variable "name" {
  description = "Hostname for the VM."
  type        = string
}

variable "subnet_id" {
  description = "Resource ID for a subnet. NOTE!! Not actually used as we're hardcoding."
  type        = string
  default     = ""
}

variable "asg_id" {
  description = "Optional resource ID for an application security group"
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Name for the resource group. Required."
  type        = string
  default     = "arc-onprem-servers"
}

//=============================================================

variable "size" {
  description = "Azure virtual machine size."
  default     = "Standard_A1_v2"
}

variable "location" {
  description = "Azure region for the on prem VM."
  default     = "UK South"
}

variable "tags" {
  description = "Map of tags for the resources created by this module. Use arc.tags for the Arc Connected Server tags if onboarding."
  type        = map(string)
  default     = {}
}

//=============================================================

variable "admin_username" {
  description = "VM admin username."
  default     = "azureuser"
}

variable "admin_ssh_public_key_file" {
  description = "Public key file to use."
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_ssh_public_key" {
  description = "SSH public key. Has priority over the admin_ssh_public_key_file variable"
  type        = string
  default     = ""
}

variable "dns_label" {
  description = "Shortname for the public IP's FQDN."
  type        = string
  default     = null
}

//==============================================================

variable "workspace" {
  description = "Object defining the log analytics workspace."

  type = object({
    id  = string
    key = string
  })

  sensitive = true
  default   = null
}
