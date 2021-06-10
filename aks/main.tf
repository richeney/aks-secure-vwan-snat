resource "azurerm_resource_group" "aks" {
  name     = "${var.name}-aks"
  location = var.location
}

resource "azurerm_virtual_network" "aks" {
  name                = "${var.name}-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = var.address_spaces
}

resource "azurerm_subnet" "aks" {
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.address_prefix.aks]
}

resource "azurerm_subnet" "test" {
  name                 = "test"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.address_prefix.test]
}

resource "azurerm_subnet" "loadbalancer" {
  name                 = "loadbalancer"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = [var.address_prefix.loadbalancer]
}

//====================================================================

resource "azurerm_user_assigned_identity" "aks" {
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  name                = var.name
}

resource "azurerm_role_assignment" "aks" {
  scope                = azurerm_resource_group.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

//====================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.name}-aks"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.name}-${var.admin_username}-test"

  default_node_pool {
    name               = "default"
    node_count         = 3
    vm_size            = "Standard_D2_v2"
    availability_zones = [1, 2, 3]
    vnet_subnet_id     = azurerm_subnet.aks.id
  }

  network_profile {
    network_plugin = "kubenet"
    pod_cidr       = "172.21.0.0/16"
  }

  identity {
    type                      = "UserAssigned"
    user_assigned_identity_id = azurerm_user_assigned_identity.aks.id
  }
}

resource "kubernetes_pod" "ubuntu" {
  metadata {
    name = "ubuntu"
    labels = {
      app = "ubuntu"
    }
  }

  spec {
    container {
      name    = "ubuntu"
      image   = "ubuntu:latest"
      command = ["/bin/sleep", "3650d"]
    }
  }
}

resource "kubernetes_service" "ubuntu" {
  metadata {
    name = "ubuntu-service"
    annotations = {
      "service.beta.kubernetes.io/azure-load-balancer-internal"        = "true"
      "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" = azurerm_subnet.loadbalancer.name
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      port        = 80
      target_port = 80
    }

    selector = {
      app = kubernetes_pod.ubuntu.metadata.0.labels.app
    }
  }
}

//====================================================================

module "testvm" {
  source              = "../module/linux"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  depends_on          = [azurerm_subnet.test]

  name           = var.name
  admin_username = var.admin_username
  size           = "Standard_DS2_v2"
  subnet_id      = azurerm_subnet.test.id
  dns_label      = "${var.name}-${var.admin_username}-test"
  ip_address     = cidrhost(azurerm_subnet.test.address_prefixes[0], 4)
}
