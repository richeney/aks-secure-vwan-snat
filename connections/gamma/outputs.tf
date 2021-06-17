output "nat_rule_ids" {
  value = values(null_resource.nat_rules)[*].triggers.id
}

output "egress_nat_rule_ids" {
  value = [ for rules in values(null_resource.nat_rules)[*].triggers: rules.id if rules.mode == "EgressSnat" ]
}

output "ingress_nat_rule_ids" {
  value = [ for rules in values(null_resource.nat_rules)[*].triggers: rules.id if rules.mode == "IngressSnat" ]
}
