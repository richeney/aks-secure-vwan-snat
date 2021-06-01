# Secure Virtual WAN with NAT to public IP and then NAT per connection

References:

* <https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-new>
* <https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ingress-controller-add-on-existing>
* <https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity>
* <https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-annotations>
* <https://docs.microsoft.com/en-us/azure/virtual-wan/>
* <https://docs.microsoft.com/en-us/azure/virtual-wan/virtual-wan-site-to-site-portal>
* <https://docs.microsoft.com/en-us/azure/virtual-wan/nat-rules-vpn-gateway>
* <https://docs.microsoft.com/en-us/azure/firewall/>
* <https://docs.microsoft.com/en-us/azure/firewall/snat-private-range>
* <https://docs.microsoft.com/en-us/azure/firewall-manager/>
* <https://docs.microsoft.com/en-us/azure/firewall-manager/secure-cloud-network>

## Prereq

```bash
az extension add --name aks-preview
```

## Telco sites

Note the terraform.tfvars - example site:

```json
sites = [
  {
    name          = "alpha"
    address_space = "10.1.0.0/24"
    asn           = 66521
  }
]
```

1. Clone

    ```bash
    git clone https://github.com/richeney/commify
    cd commify
    ```

1. Deploy

    ```bash
    terraform init
    terraform apply --auto-approve
    ```

    > NB. Rerun `terraform apply` if there is a failure.

## Secure Virtual WAN

1. Followed <https://docs.microsoft.com/en-us/azure/firewall-manager/secure-cloud-network>.

    Notes:

    * Used 201.1.0.0/24 for the hub address space. (Smallest possible is /24.)
    * Include VPN Gateway but don't select Security Partner Providers
    * Standard Firewall enabled with 1 public IP and default Deny Policy

1. Added alpha site using s2svpn.sh
1. Check BGP with routes.sh

> Will add beta and gamma later.


## AKS spoke vNet

Set for kubenet, optional Application Gateway Ingress Controller

1. Create the resource group

    ```bash
    az group create --name "commify-aks" --location "West Europe"
    # export AZURE_DEFAULTS_GROUP="commify"
    # export AZURE_DEFAULTS_LOCATION="West Europe"
    ```

1. Create the virtual network

    ```bash
    az network vnet create --name commify-aks \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --address-prefixes 172.21.0.0/16 197.6.0.0/24 10.76.0.0/27
    ```

1. Add the subnets

    Pods, using a nice big private CIDR address prefix.

    ```bash
    az network vnet subnet create --name aks \
      --address-prefixes 172.21.0.0/16 \
      --vnet-name "commify-aks" \
      --resource-group "commify-aks"
    ```

    Application Gateway, using a smaller public address prefix. (Optional.)

    ```bash
    az network vnet subnet create --name appgw \
      --address-prefixes 197.6.0.0/24 \
      --vnet-name "commify-aks" \
      --resource-group "commify-aks"
    ```

    Small private test subnet for the test VM.

    ```bash
    az network vnet subnet create --name test \
      --address-prefixes 10.76.0.0/27 \
      --vnet-name "commify-aks" \
      --resource-group "commify-aks"
    ```

1. Grab the virtual network resource ID

    ````bash
    vnetId=$(az network vnet show --name commify-aks \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

## Managed Identity

1. Create a user managed assigned identity

    ```bash
    msiId=$(az identity create --name "commify" \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

## VM

1. Create a test VM

    ```bash
    az vm create --name commify \
    --resource-group commify-aks --location westeurope \
    --public-ip-address-dns-name commify-richeney \
    --image ubuntults \
    --size Standard_DS2_v2 \
    --vnet-name commify-aks --subnet test \
    --generate-ssh-keys
    ```

1. Test SSH connectivity

    ```bash
    ssh commify-richeney.westeurope.cloudapp.azure.com
    ```

    Then `exit`.

## Add the spoke to the Virtual WAN

Using default route tables initially. Will get more creative later when we need to NAT.

1. Used spoke.sh

## Check connectivity from test VM to alpha VM

Spoke test VM should be 10.76.0.4, and alpha VM will be 10.1.0.4.

1. SSH back on to the test

    ```bash
    ssh commify-richeney.westeurope.cloudapp.azure.com
    ```

1. SSH to alpha and check source IP

    ```bash
    ssh 10.1.0.4
    ```

## Set SNAT

1. Grab firewall ID

1. Set firewall to SNAT to private addresses

    ```bash
    az network firewall update \
-n <fw-name> \
-g <resourcegroup-name> \
--private-ranges 192.168.1.0/24 192.168.1.10 IANAPrivateRanges
    ```


## AKS with Application Gateway Ingress Controller

1. Grab the virtual network resource ID

    ````bash
    vnetId=$(az network vnet show --name commify-aks \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

1. Create a user managed assigned identity

    ```bash
    msiId=$(az identity create --name "commify" \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

1. Deploy the AKS cluster

    ```bash
    az aks create --name commify-aks \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --network-plugin kubenet \
      --pod-cidr "172.24.0.0/14" \
      --vnet-subnet-id $vnetId/subnets/aks \
      --service-cidr "10.0.0.0/16" \
      --enable-addons ingress-appgw \
      --outbound-type userDefinedRouting \
      --appgw-name appGwIngressController \
      --appgw-subnet-id $vnetId/subnets/appgw \
      --zones 1 2 3 \
      --node-vm-size Standard_DS2_v2 \
      --admin-username azureuser \
      --generate-ssh-keys \
      --assign-identity $msiId
    ```

    Notes

    * kubenet, so pod CIDR is _not_ in the subnet address space
    * can specify -vnet-subnet-id and -appgw-subnet-id if required
    the service-cidr is private and non-routable. Default shown.

1. Check it is working

    ```bash
    az aks get-credentials --name commify-aks --resource-group commify-aks
    kubectl apply -f aspnetapp.yaml
    kubectl apply -f inspectorgadget.yaml
    ```

1. Create a test VM

    ```bash
    az vm create --name commify \
    --resource-group commify-aks --location westeurope \
    --public-ip-address-dns-name commify-richeney \
    --image ubuntults \
    --size Standard_DS2_v2 \
    --vnet-name commify-aks --subnet appgw \
    --generate-ssh-keys
    ```

## Deleting notes

You have to remove pods that have AGIC annotations in order to remove the aks cluster. Do I need AGIC?

Test with single VM and IP SNAT and S2S NAT.
