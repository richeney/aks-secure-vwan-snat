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

az extension add --name azure-firewall --only-show-errors

hubrg=commify-secure-hub
location=westeurope

aksrg=commify-aks
aks=commify-aks

vwan=$(az network vwan list --resource-group $hubrg --output tsv --query [0].name)
info "Virtual WAN: $vwan"
hub=$(az network vhub list --resource-group commify-secure-hub --output tsv --query "[?ends_with(virtualWan.id, 'virtualWans/"$vwan"') && location == '"$location"']|[0].name")
info "Hub: $hub"
fw=$(az network firewall list --resource-group $hubrg --output tsv --query "[?ends_with(virtualHub.id, '"$hub"')]|[0].name")
fwId=$(az network firewall show --name $fw --resource-group $hubrg --output tsv --query id)

enableDnsProxy=$(az network firewall show --ids $fwId --query '"Network.DNS.EnableProxy"' --output tsv)

if ${enableDnsProxy:-false}
then
  info "Firewall $fw has enable-dns-proxy set to true. ✅"
else
  info "Updating firewall $fw with enable-dns-proxy=true..."
  az network firewall update --ids $fwId --enable-dns-proxy true
fi

info "Creating Route Table \"AzureFirewall\"..."
fwPrivateIp=$(az network firewall show --ids $fwId --query "hubIpAddresses.privateIpAddress" --output tsv)
az network route-table create --name AzureFirewall --resource-group $hubrg --location $location
az network route-table route create --name default_to_fw --route-table-name AzureFirewall --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $fwPrivateIp --resource-group $hubrg
az network route-table route create --name fw_to_internet --route-table-name AzureFirewall --address-prefix $fwPrivateIp/32 --next-hop-type Internet --resource-group $hubrg
routeTableId=$(az network route-table show --name AzureFirewall --resource-group $hubrg --output tsv --query id)

info "Assigning route table to AKS node subnet..."
aksSubnetId=$(az aks show --name $aks --resource-group $aksrg --output tsv --query "agentPoolProfiles[0].vnetSubnetId" --only-show-errors)
az network vnet subnet update --ids $aksSubnetId --route-table $routeTableId

exit 0