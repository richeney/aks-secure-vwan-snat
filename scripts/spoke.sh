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

hubrg=commify-secure-hub
vwan=commify-virtual-wan

spokerg=commify-aks
spokeVnet=commify-aks

loc="West Europe"


info "Getting vwan and spoke vnet details..."
vwanId=$(az network vwan show --name $vwan --resource-group $hubrg --output tsv --query id)
hub=$(az network vhub list --resource-group $hubrg --output tsv --query "[?virtualWan.id == '"$vwanId"'].name")
spokeVnetId=$(az network vnet show --name $spokeVnet --resource-group $spokerg --output tsv --query id)

info "Connecting hub $hub to spoke vnet $spokeVnet..."
az network vhub connection create --name $spokeVnet \
  --resource-group $hubrg \
  --vhub-name $hub \
  --remote-vnet $spokeVnetId \
  --labels default

[[ $? == 0 ]] && info "Complete" || error "Virtual connection failed"

exit 0