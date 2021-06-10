module "site" {
  source         = "../module/site"
  for_each       = { for site in var.sites : site.name => site }
  name           = "${var.name}-${each.value.name}"
  address_space  = each.value.address_space
  asn            = each.value.asn
  admin_username = var.admin_username
}