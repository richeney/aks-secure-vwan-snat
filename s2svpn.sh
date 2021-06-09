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

site=${1:-alpha}
natRule="$2"

hubrg=$prefix-secure-hub
vwan=$prefix-virtual-wan

siterg=$prefix-$site
siteVpnGw=$prefix-${site}-vpngw
sharedkey="c0mm1fy"
loc="West Europe"

info "Getting VPN gateway info for $site..."
siteVpnGwId=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query id)
siteVpnGwIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]")
siteVpnGwBgpIp=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.bgpPeeringAddress")
siteVpnGwAsn=$(az network vnet-gateway show --name $siteVpnGw --resource-group $siterg --output tsv --query "bgpSettings.asn")
info "The $site site's VPN GW is $siteVpnGw, the IP address is $siteVpnGwIp, BGP address is $siteVpnGwBgpIp and ASN is $siteVpnGwAsn."

info "Creating remote site $site"
az network vpn-site create --name $site --ip-address $siteVpnGwIp --resource-group $hubrg --asn $siteVpnGwAsn --bgp-peering-address $siteVpnGwBgpIp --virtual-wan $vwan --location "$loc" --device-model VNETGW --device-vendor Azure --link-speed 100

info "Creating connection from hub to site $site"
hub=$(az network vwan list --resource-group $hubrg --query [0].name)
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")
az network vpn-gateway connection create --gateway-name $hubVpnGw --name to-$site --remote-vpn-site $site --resource-group $hubrg --shared-key $sharedkey --enable-bgp true --no-wait

info "Getting VPN gateway info for hub..."
hubVpnGwId=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query id)
hubVpnGwIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].tunnelIpAddresses[0]")
hubVpnGwBgpIp=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.bgpPeeringAddresses[?ipconfigurationId == 'Instance0'].defaultBgpIpAddresses")
hubVpnGwAsn=$(az network vpn-gateway show --name $hubVpnGw --resource-group $hubrg --output tsv --query "bgpSettings.asn")
hubVpnGwKey=$(az network vpn-gateway connection show --gateway-name $hubVpnGw --name to-$site --resource-group $hubrg --output tsv --query "sharedKey")
info "VPN gateway $hubVpnGw in hub $hub has IP address of $hubVpnGwIp, BGP address is $hubVpnGwBgpIp and ASN is $hubVpnGwAsn."

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