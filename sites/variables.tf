variable "sites" {
  description = "List of sites."
  type = list(object({
    name          = string
    address_space = string
    asn           = number
  }))

  default = [
    {
      name          = "alpha"
      address_space = "3.1.0.0/24"
      asn           = 66521
    },
    {
      name          = "beta"
      address_space = "3.2.0.0/24"
      asn           = 66522
    },
    {
      name          = "gamma"
      address_space = "10.3.0.0/24"
      asn           = 66523
    }
  ]
}

variable "name" {
  description = "Name used to prefix resource names etc."
  type        = string
  default     = "example"
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "admin_username" {
  description = "For VM admin name."
  default     = "azureuser"
}
