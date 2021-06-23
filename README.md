# Virtual WAN with NAT

## Description

Example Terraform configs for

* Three sites, alpha, beta and gamma, Each has
    * a single virtual network
    * a single VM for testing
    * a virtual network gateway
* The POC requirement says that the address space for the gamma site needs NAT
    * Original address space is 10.3.0.0/24
    * Will have a 1:1 static IngressSnat rule mapping the original address space to "3.3.0.0/24"
* AKS is using a small public address space and a separate subnet for the load balancer.
    * Small Ubuntu pod for testing
    * Plus a test VM in the same subnet.
* Virtual WAN with NAT rules applied to one connection (gamma) using REST API in null providers for the nat rules and for the connection.
    * At the time of creation there is no support for Virtual WAN NAT rules in the azurerm Terraform provider

## Prereqs

1. Azure subscription
1. Bash Cloud Shell (<https://shell.azure.com>)

Alternatively you can use your preferred editor and terminal if you have your laptop set up with a local Bash environment. You will need the Azure CLI, plus jq, terraform and git binaries installed.

My setup is documented [here](https://azurecitadel.com/setup).

## Order

The repo contains six linked Terraform configs. Some read the remote state files of other configs.

* The ./sites and ./aks configs are deployed initially and may be created in parallel
* The ./vwan config links to the AKS vnet
* The ./connections/alpha, ./connections/beta, ./connections/gamma, which access the state of both the sites and the virtual WAN

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

    This readme assumes you are in your home directory.

## AKS

Deploy the test AKS environment.

Note that is uses a tiny public address prefix by default as per the POC brief.

> Feel free to change this to a purely private address space and update the subnet address prefixes appropriately.

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

> Save time by running  this in a separate terminal or Cloud Shell session whilst the AKS environment is deploying.

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

## Testing

### Configure kubectl

1. kubectl binary

    Install kubectl.

    ```bash
    az aks install-cli
    ```

1. kubeconfig

    Merge in the kubeconfig details.

    ```bash
    az aks get-credentials --name example-aks --resource-group example-aks
    ```

1. Checks

    Check the nodes.

    ```bash
    kubectl get nodes
    ```

    Check the pod.

    ```bash
    kubectl get pods
    ```

### Configure the pod

1. Run bash on the pod

    ```bash
    kubectl exec --stdin --tty ubuntu -- /bin/bash
    ```

1. Install openssh

    ```bash
    apt-get update && apt-get install openssh-client -y
    ```

1. Exit

    ```bash
    exit
    ```

1. Upload the private SSH key

    ```bash
    kubectl cp ~/.ssh/id_rsa ubuntu:/id_rsa
    ```

### Test connectivity to a VM

NIC IP addresses

| VM | IP address | Notes |
|---|---|---|
| example | 10.76.0.4 | in the AKS vnet |
| example-alpha | 3.1.0.4 ||
| example-beta | 3.2.0.4 ||
| example-gamma | 3.3.0.4 | NAT from 10.3.0.4 |

> Assumes he variable defaults in the repo have been used.

Check the effective routes on each VM's NIC. The routing should be present (including the SNAT range) for AKS to sites, but there should not be any route information for one site to connect to another.

1. Run bash on the ubuntu pod


    ```bash
    kubectl exec --stdin --tty ubuntu -- /bin/bash
    ```

1. SSH to the VM

    The command is connecting to the example-alpha VM.

    ```bash
    ssh -i id_rsa azureuser@3.1.0.4
    ```

    If it connects then the WAN links and/or NAT rules are working correctly.

1. Display the source IP

    ```bash
    echo $SSH_CLIENT | awk '{print $1}'
    ```

    The command should display 1.2.3.4, 1.2.3.5 or 1.2.3.6 depending on which AKS node is hosting the ubuntu pod.

## Troubleshooting

1. Check

## Notes for gamma

The gamma connection uses the preview NAT feature to 1:1 map 10.3.0.0/24 to 3.3.0.0/24. (The CIDR subnet masks must be the same length.)

The ./connections/gamma/gamma.tf file creates the JSON object in the locals and then uses jsonencode as part of the REST API call.

A ./connections/gamma/gamma.tf.hardcoded file is also included to show how a simplified file would look without all of the functions etc.

## References:

* <https://docs.microsoft.com/azure/virtual-wan/nat-rules-vpn-gateway>
* <https://aka.ms/terraform>
* <https://docs.microsoft.com/rest/api/virtualwan/nat-rules/create-or-update>
* <https://docs.microsoft.com/rest/api/virtualwan/vpn-connections/create-or-update>