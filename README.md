# Virtual WAN with NAT

## Description

ADD A GRAPHIC.

Example Terraform configs for

* Three sites, alpha, beta and gamma, Each has a single virtual network, a single VM and a network gateway. Address space conflict between beta and gamma.
* AKS using a small public address space and a separate subnet for the load balancer. Small Ubuntu pod for testing, plus a VM in the same subnet.
* Virtual WAN with NAT rules applied to one connection using REST API in a null provider.

## Prereqs

1. Azure subscription
1. Bash Cloud Shell (<https://shell.azure.com>)

Alternatively you can use your preferred editor and terminal if you have your laptop set up with a local Bash environment. You will need the Azure CLI, plus jq, terraform and git binaries installed.

My setup is documented [here](https://azurecitadel.com/setup).

## Order

The sensible order is:

1. Clone the repo
1. Create the AKS virtual network and cluster
1. Simultaneously create the sites
1. Create the virtual WAN, which will connect to the AKS cluster's virtual network
1. Create the connections, linking the virtual WAN to the three sites

## Clone

1. Log into the bash environment
1. Clone the repo

    ```bash
    git clone https://github.com/richeney/aks-vwan-nat
    ```

    This readme assumes you are in the

## AKS

Deploy the test AKS environment.

Note that is uses a tiny public address prefix by default as per my POC brief.

> Feel free to change this to a purely  private address space and update the subnet address prefixes appropriately.

The loadbalancer subnet is specified by the loadbalancer annotations in the YAML kubernetes service definition so that it doesn't consume IP addresses from the aks subnet.

1. Change directory

    ```bash
    cd ~/aks-vwan-nat/aks
    ```

1. Initialise

    ```bash
    terraform init
    ```

1. Deploy

    ```bash
    terraform apply
    ```

    Note that the two yaml files are not used but are included for reference. (The pod and service are defined in the main.tf.)

## Sites

Repeat for the sites folder to deploy the three sites. These represent different branches or customers. Note that if you have real branches with S2S VPN devices then you don't need the sites area. You will have to adjust the connections later for your target environments.

> You can run this in a separate termain or CLoud Shell session whilst the AKS environment is deploying if you need to save time,.

1. Change directory

    ```bash
    cd ~/aks-vwan-nat/sites
    ```

1. Initialise

    ```bash
    terraform init
    ```

1. Deploy

    ```bash
    terraform apply
    ```

Note the default value for var.sites in the variables.tf. The beta and gamma sites have overlapping address spaces.

## Virtual WAN

Deploy the Azure Virtual WAN. This will connect to the AKS virtual network.

1. Change directory

    ```bash
    cd ~/aks-vwan-nat/vwan
    ```

1. Initialise

    ```bash
    terraform init
    ```

1. Display the AKS virtual network ID

    ```bash
    az network vnet show --name example-aks --resource-group example-aks --query id --output tsv
    ```

1. Create terraform.tfvars

    Create a terraform.tfvars file to specify the value for var.aks_virtual_network_id.

    Example file:

    ```text
    aks_virtual_network_id = "/subscriptions/2ca40be1-7e80-4f2b-92f7-06b2123a68cc/resourceGroups/example-aks/providers/Microsoft.Network/virtualNetworks/example-aks"
    ```

    > Alternatively you can just run this one command:
    >
    > ```bash
    > echo "aks_virtual_network_id = $(az network vnet show --name example-aks --resource-group example-aks --query id --output json)" > terraform.tfvars
    > ```

1. Deploy

    ```bash
    terraform apply
    ```

The azurerm_virtual_wan resource has allow_branch_to_branch_traffic set to false rather than the default of true. This fits the POC requirement.

Check the Virtual WAN in the example-vwan resource group and you should see example-hub connected to example-aks in the Virtual network connections.

Note that the local network gateways are only defined for use by the reverse connections (those going from the branch sites back to the hub) from the sites' virtual network gateways. You would not need these for a real branch site environment.

## Connections

The terraform.tf in this folder uses remote state files from both the vwan and the sites deployments so these must be

The connections in alpha.tf and beta.tf are effectively the same.

Note that you don't need the azurerm_virtual_network_gateway_connection resource for a real branch site environment.

The gamma.tf uses a NAT rule, which is a preview service on Azure Virtual WAN at the time of repo creation and is not yet supported in the Terraform azurerm provider. It has been implemented as a couple of null provider based REST API calls. Once to create the NAT rule definition within the VPN gateway, and the other to update the azurerm_vpn_gateway_connection and associate the NAT rule.

Each site is in its own subdirectory to make it simpler to 'switch' individual connections on and off. Example for alpha:

1. Change directory

    ```bash
    cd ~/aks-vwan-nat/connections/alpha
    ```

1. Initialise

    ```bash
    terraform init
    ```

1. Deploy

    ```bash
    terraform apply
    ```

##