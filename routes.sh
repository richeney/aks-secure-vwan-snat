#!/bin/bash
# Requires az extension add --name virtual-wan

error()
{
  if [[ -n "$@" ]]
  then
    tput setaf 1
    echo "ERROR: $@" >&2
    tput sgr0
  fi

  exit 1
}

info()
{
  if [[ -n "$@" ]]
  then
    tput setaf 6
    echo "$@" >&2
    tput sgr0
  fi

  return 0
}

site=${1:-alpha}

hubrg=commify-secure-hub
vwan=commify-virtual-wan
siterg=commify-$site

siteVpnGw=commify-${site}-vpngw
info "Remote VPN Gateway:" $siteVpnGw

hub=$(az network vwan list --resource-group $hubrg --output tsv --query [0].name)
info "Hub: $hub"
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")
info "Hub VPN Gateway:" $hubVpnGw
hubVpnGwBgpIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses" --output tsv)
info "Hub VPN Gateway BGP address:" $hubVpnGwBgpIp

info "Verify BGP peer status"
az network vnet-gateway list-bgp-peer-status --name $siteVpnGw --resource-group $siterg --output table

info "Display routes advertised from $siteVpnGw to hub $hub"
az network vnet-gateway list-advertised-routes --name $siteVpnGw --resource-group $siterg --peer $hubVpnGwBgpIp --output table

info "Display routes learned by $siteVpnGw from hub $hub"
az network vnet-gateway list-learned-routes --name $siteVpnGw --resource-group $siterg --output table

exit 0