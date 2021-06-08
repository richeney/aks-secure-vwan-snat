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

site=gamma
natRule=gamma-ingress

hubrg=commify-secure-hub
vwan=commify-virtual-wan

siterg=commify-$site
siteVpnGw=commify-${site}-vpngw
sharedkey="c0mm1fy"
loc="West Europe"

hubrgId=$(az group show --name $hubrg --query id --output tsv)
sitergId=$(az group show --name $siterg --query id --output tsv)

info "Getting VPN gateway info for $site..."
siteVpnGwIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]")
siteVpnGwBgpIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddress")
siteVpnGwAsn=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.asn")
info "The $site site's VPN GW is $siteVpnGw, the IP address is $siteVpnGwIp, BGP address is $siteVpnGwBgpIp and ASN is $siteVpnGwAsn."

info "Getting VPN gateway info for secure hub..."
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")
hubVpnGwId=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query id)
hubVpnGwIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].tunnelIpAddresses[0]")
hubVpnGwBgpIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses")
hubVpnGwAsn=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.asn")
# hubVpnGwKey=$(az network vpn-gateway connection show --gateway-name $hubVpnGw --name to-$site --resource-group $hubrg --output tsv --query "sharedKey")
info "VPN gateway $hubVpnGw in secure hub $hub has IP address of $hubVpnGwIp, BGP address is $hubVpnGwBgpIp and ASN is $hubVpnGwAsn."

info "Creating NAT rule gamma-ingress"
uri="https://management.azure.com/$hubVpnGwId/natRules/gamma-ingress?api-version=2020-11-01"
az rest --method put --body "@nat-rule-gamma-ingress.json" --uri "$uri"


info "Creating remote site $site"
# az network vpn-site create --name $site --ip-address $siteVpnGwIp --resource-group $hubrg --asn $siteVpnGwAsn --bgp-peering-address $siteVpnGwBgpIp --virtual-wan $vwan --location "$loc" --device-model VNETGW --device-vendor Azure --link-speed 100

uri="$hubrgId/providers/Microsoft.Network/vpnSites/{vpnSiteName}?api-version=2020-11-01"


info "Creating connection from secure hub to site $site"
hub=$(az network vwan list --resource-group $hubrg --query [0].name)
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")
az network vpn-gateway connection create --gateway-name $hubVpnGw --name to-$site --remote-vpn-site $site --resource-group $hubrg --shared-key $sharedkey --enable-bgp true --no-wait

info "Getting VPN gateway info for secure hub..."
hubVpnGwId=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query id)
hubVpnGwIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].tunnelIpAddresses[0]")
hubVpnGwBgpIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses")
hubVpnGwAsn=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.asn")
hubVpnGwKey=$(az network vpn-gateway connection show --gateway-name $hubVpnGw --name to-$site --resource-group $hubrg --output tsv --query "sharedKey")
info "VPN gateway $hubVpnGw in secure hub $hub has IP address of $hubVpnGwIp, BGP address is $hubVpnGwBgpIp and ASN is $hubVpnGwAsn."

info "Creating local network gateway commify-${site}-lng"
az network local-gateway create --resource-group $siterg --name commify-${site}-lng --gateway-ip-address $hubVpnGwIp --location "$loc" --asn $hubVpnGwAsn --bgp-peering-address $hubVpnGwBgpIp

if [[ -n "$natRule" ]]
then
  echo "Creating connection from site $site to secure hub with ingress nat rule $natRule"
  natRuleId="$hubVpnGwId/natRules/$natRule"
  az network vpn-connection create --name to-secure-hub --vnet-gateway1 $siteVpnGw --resource-group $siterg --local-gateway2 commify-${site}-lng --location "$loc" --shared-key $hubVpnGwKey --enable-bgp --ingress-nat-rule $natRuleId
else
  echo "Creating connection from site $site to secure hub"
  az network vpn-connection create --name to-secure-hub --vnet-gateway1 $siteVpnGw --resource-group $siterg --local-gateway2 commify-${site}-lng --location "$loc" --shared-key $hubVpnGwKey --enable-bgp
fi

exit 0