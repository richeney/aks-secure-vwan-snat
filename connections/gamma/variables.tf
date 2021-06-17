variable "nat_rules" {
  type = list(object({
    name = string
    mode = string
    mappings = list(object({
      internal = string
      external = string
    }))
  }))

  default = []

  validation {
    condition     = alltrue([for mode in var.nat_rules[*].mode : contains(["ingress", "egress"], mode)])
    error_message = "Mode should be either ingress or egress."
  }
}
