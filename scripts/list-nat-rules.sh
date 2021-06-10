#!/bin/bash
# Based on <https://docs.microsoft.com/en-us/rest/api/virtualwan/nat-rules/create-or-update>
# Preview feature with no matchin az cli command

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
hubrg=$prefix-secure-hub
hubrgId=$(az group show --name $hubrg --query id --output tsv)
hubVpnGw=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].name")

uri="https://management.azure.com/$hubrgId/providers/Microsoft.Network/vpnGateways/$hubVpnGw/natRules?api-version=2020-11-01"

az rest --method get --uri "$uri"