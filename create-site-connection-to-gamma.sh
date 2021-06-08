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

hubrg=commify-secure-hub
json=site-connection-to-gamma.json

[[ -f $json ]] || error "Cannot find $json."
[[ -s $json ]] || error "File $json is empty."

name=to-gamma

# hubrgId=$(az group show --name commify-secure-hub --query id --output tsv)
hubVpnGwId=$(az network vpn-gateway list --resource-group $hubrg --output tsv --query "[0].id")

uri="https://$hubVpnGwId/vpnConnections/$name?api-version=2020-11-01"


az rest --method put --body "@$json" --uri "$uri"