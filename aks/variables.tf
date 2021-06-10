variable "name" {
  description = "Name used to prefix resource names etc."
  type        = string
  default     = "example"
}

variable "address_spaces" {
  type    = list(string)
  default = ["1.2.3.0/29", "10.76.0.0/24"]
}

variable "address_prefix" {
  type = object({
    aks          = string
    test         = string
    loadbalancer = string
  })

  default = {
    aks          = "1.2.3.0/29"
    test         = "10.76.0.0/27"
    loadbalancer = "10.76.0.32/27"
  }
}

//===================================================================

variable "location" {
  type    = string
  default = "West Europe"
}

variable "admin_username" {
  description = "For VM admin name."
  default     = "azureuser"
}
