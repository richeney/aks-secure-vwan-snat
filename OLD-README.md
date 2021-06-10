# Secure Virtual WAN with NAT to public IP and then NAT per connection

> **OK, this README.md needs some serious validation as much of it has been put togthere out of order, with a mix of Terraform, CLI and Portal.** It is incomplete, and references to commify and richeney need to be removed.

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

```text
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
    * In Settings -> Configuration, set Branch-to-branch as disabled.

1. Added alpha site using s2svpn.sh
1. Check BGP with routes.sh

> Will add beta and gamma later.

## AKS spoke vNet

Set for kubenet, separate loadbalancer subnet plus identity

1. Create the resource group

    ```bash
    az group create --name "commify-aks" --location "West Europe"
    # export AZURE_DEFAULTS_GROUP="commify"
    # export AZURE_DEFAULTS_LOCATION="West Europe"
    ```

1. Create the virtual network

    Tiny address space for "public" AKS nodes, plus private space for internal load balancer and test VM.

    ```bash
    az network vnet create --name commify-aks \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --address-prefixes 1.2.3.0/29 10.76.0.0/24
    ```

1. Add the subnets

    AKS nodes.

    ```bash
    az network vnet subnet create --name aks \
      --address-prefixes 1.2.3.0/29 \
      --vnet-name "commify-aks" \
      --resource-group "commify-aks"
    ```

    Load Balancer subnet

    ```bash
    az network vnet subnet create --name loadbalancer \
      --address-prefixes 10.76.0.32/27 \
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
    az identity create --name "commify" \
      --location "West Europe" \
      --resource-group "commify-aks"
    ```

1. Assign to the virtual network

    ```bash
    msiAppId=$(az identity show --name commify --resource-group commify-aks --query principalId --output tsv)
    az role assignment create --role "Network Contributor" --assignee $msiAppId --scope $vnetId
    ```

## Test VM

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

Using default route tables in vWAN initially. Will get more creative later when we need to NAT.

1. Used spoke.sh

## Check connectivity from test VM to alpha VM

Spoke test VM should be 10.76.0.4, and alpha VM will be 10.1.0.4.

1. Copy up your SSH key

    ```bash
    scp ~/.ssh/id_rsa richeney@commify-richeney.westeurope.cloudapp.azure.com:~/.ssh/
    ```

1. SSH back on to the test VM

    ```bash
    ssh commify-richeney.westeurope.cloudapp.azure.com
    ```

1. SSH to alpha

    ```bash
    ssh 10.1.0.4
    ```

1. Display the source IP

  ```bash
  echo $SSH_CLIENT | awk '{print $1}'
  ```

  Expected output: `10.76.0.4`.

  Exit back to your machine.

## AKS

1. Grab the virtual network resource ID again

    ```bash
    vnetId=$(az network vnet show --name commify-aks \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

1. Create a user managed assigned identity

    ```bash
    msiId=$(az identity show --name "commify" \
      --resource-group "commify-aks" \
      --query id --output tsv)
    ```

1. Deploy the AKS cluster

    Very standard AKS deployment, except using precreated subnet and user assigned identity

    ```bash
    az aks create --name commify-aks \
      --location "West Europe" \
      --resource-group "commify-aks" \
      --network-plugin kubenet \
      --pod-cidr "172.21.0.0/16" \
      --vnet-subnet-id $vnetId/subnets/aks \
      --service-cidr "10.0.0.0/16" \
      --zones 1 2 3 \
      --node-vm-size Standard_DS2_v2 \
      --admin-username azureuser \
      --generate-ssh-keys \
      --assign-identity $msiId
    ```

    Notes

    * kubenet, so pod CIDR is _not_ in the subnet address space
    * the service-cidr is private and non-routable. Default shown.

1. Merge the AKS credentials

    ```bash
    az aks get-credentials --name commify-aks --resource-group commify-aks
    ```

1. Confirm kubectl works

    ```bash
    kubectl get nodes
    ```

1. Inspector Gadget deployment with private loadbalancer

    ```bash
    kubectl apply -f inspectorgadget.yaml
    ```

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

1. Install links on the test VM and access Inspector Gadget

    ```bash
    ssh commify-richeney.westeurope.cloudapp.azure.com
    sudo apt install links -y
    links 10.76.0.36
    ```

    You should be on the Inspector Gadget homepage. If so the internal loadbalancer service is working.

    You can use cursor keys to browse.

1. Create a test ubuntu pod

    ```bash
    kubectl apply -f ubuntu.yaml
    ```

1. Log on and install openssh

    ```bash
    kubectl exec --stdin --tty ubuntu -- /bin/bash
    apt-get update && apt-get install openssh-client -y
    exit
    ```

1. Upload the private key

    ```bash
    kubectl cp ~/.ssh/id_rsa ubuntu:/id_rsa
    ```

1. Log back in and SSH to the test VM

    ```bash
    kubectl exec --stdin --tty ubuntu -- /bin/bash
    ssh -i id_rsa richeney@10.76.0.4
    echo $SSH_CLIENT | awk '{print $1}'
    ```

    OK, so the pod's egress traffic should NAT through the bridge to the node IP address. (E.g. 1.2.3.4-6.)

    Exit back to your laptop.

## Add beta site

1. Run s2svpn.sh again, specifying the site

    ```bash
    ./s2svpn.sh beta
    ```

1. Check

    If you test ssh from the container and or test VM then it should reach the hosts in both alpha and beta, but check the effective routes on the NICs and they cannot see each other's address spaces as the Virtual WAN's properties.allowBranchToBranchTraffic boolean is set to false.

## Add beta site

1. s2svpn.sh

    ```bash
    ./s2svpn.sh gamma
    ```
