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

prefix=commify

site=gamma
natRule=gamma-ingress

hubrg=$prefix-secure-hub
vwan=$prefix-virtual-wan

siterg=$prefix-$site
siteVpnGw=$prefix-${site}-vpngw
sharedkey="c0mm1fy"
loc="West Europe"

hubrgId=$(az group show --name $hubrg --query id --output tsv)
sitergId=$(az group show --name $siterg --query id --output tsv)

info "Getting VPN gateway info for $site..."
siteVpnGwId=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query id)
siteVpnGwIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]")
siteVpnGwBgpIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddress")
siteVpnGwAsn=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.asn")
info "The $site site's VPN GW is $siteVpnGw, the IP address is $siteVpnGwIp, BGP address is $siteVpnGwBgpIp and ASN is $siteVpnGwAsn."

info "Getting VPN gateway info for hub..."
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")
hubVpnGwId=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query id)
hubVpnGwIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].tunnelIpAddresses[0]")
hubVpnGwBgpIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses")
hubVpnGwAsn=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.asn")
# hubVpnGwKey=$(az network vpn-gateway connection show --gateway-name $hubVpnGw --name to-$site --resource-group $hubrg --output tsv --query "sharedKey")
info "VPN gateway $hubVpnGw in hub $hub has IP address of $hubVpnGwIp, BGP address is $hubVpnGwBgpIp and ASN is $hubVpnGwAsn."

info "Creating NAT rule $natRule"
uri="https://management.azure.com/$hubVpnGwId/natRules/$natRule?api-version=2020-11-01"
az rest --method put --body "@nat-rule-$natRule.json" --uri "$uri"


info "Creating remote site $site"
# az network vpn-site create --name $site --ip-address $siteVpnGwIp --resource-group $hubrg --asn $siteVpnGwAsn --bgp-peering-address $siteVpnGwBgpIp --virtual-wan $vwan --location "$loc" --device-model VNETGW --device-vendor Azure --link-speed 100
uri="$hubrgId/providers/Microsoft.Network/vpnSites/$site?api-version=2020-11-01"
az rest --method put --body "@site-$site.json" --uri "$uri"
info "... note that BGP IP address in site-$site.json has been changed from 10.2.0.254 to 10.102.0.254 to match the ingress NAT rule."

info "Creating connection to-$site"
uri="$hubVpnGwId/vpnConnections/to-$site?api-version=2020-11-01"
az rest --method put --body "@site-connection-to-$site.json" --uri "$uri"

## info "Waiting for provisioning to succeed - may take up to 10 minutes"
## let n=0
## until [[ "$(az network vpn-gateway show --ids $hubVpnGwId --query provisioningState --output tsv)" != "Updated" ]]
## do
##   echo -n .
##   sleep 5
##   ((n++))
##   [[ $n > 132 ]] && error "Timed out waiting for VPN gateway to complete."
## done
## info "Succeeded. That is all that is needed for a normal connection. The following is for the remote virtul network gateway."

if [[ "$(az network local-gateway show --resource-group $siterg --name ${prefix}-hub-lng --query provisioningState --output tsv)" == "Succeeded" ]]
then
  info "Using local network gateway $prefix-hub-lng for the reverse connection"
else
  info "Creating local network gateway $prefix-hub-lng for the reverse connection"
  az network local-gateway create --resource-group $siterg --name ${prefix}-hub-lng --gateway-ip-address $hubVpnGwIp --location "$loc" --asn $hubVpnGwAsn --bgp-peering-address $hubVpnGwBgpIp
fi
hubLngId=$(az network local-gateway show --resource-group $siterg --name ${prefix}-hub-lng --query id --output tsv)

echo "Creating connection from site $site to hub"
az network vpn-connection create --name $site-to-hub --vnet-gateway1 $siteVpnGwId --resource-group $siterg --local-gateway2 $hubLngId --location "$loc" --shared-key $sharedkey --enable-bgp

exit 0