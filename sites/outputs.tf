output "site" {
  value = { for site in var.sites :
    (site.name) => {
      name                = module.site[site.name].siteinfo.name
      asn                 = module.site[site.name].siteinfo.asn
      ip_address          = module.site[site.name].siteinfo.ip_address
      bgp_peering_address = module.site[site.name].siteinfo.bgp_peering_address
    }
  }

}
