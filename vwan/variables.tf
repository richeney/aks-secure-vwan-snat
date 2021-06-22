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

variable "allow_branch_to_branch_traffic" {
  type    = bool
  default = false
}
