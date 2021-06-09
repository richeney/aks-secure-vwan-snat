variable "sites" {
  description = "List of sites."
  type = list(object({
    name          = string
    address_space = string
    asn           = number
  }))
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "admin_username" {
  description = "For VM admin name."
  default     = "azureuser"
}
