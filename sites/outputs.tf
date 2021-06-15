output "site" {
  value = { for site in var.sites :
    (site.name) => module.site[site.name].siteinfo
  }
}


/*
output "site" {
  value = { for site in var.sites :
    (site.name) => {
      name                    = module.site[site.name].siteinfo.name
      resource_group          = module.site[site.name].siteinfo.resource_group
      virtual_network_gateway = module.site[site.name].siteinfo.virtual_network_gateway
    }
  }
}
*/