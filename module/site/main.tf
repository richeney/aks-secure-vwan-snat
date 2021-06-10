resource "azurerm_resource_group" "site" {
  name     = var.name
  location = var.location
}

resource "azurerm_virtual_network" "site" {
  name                = var.name
  location            = azurerm_resource_group.site.location
  resource_group_name = azurerm_resource_group.site.name
  address_space       = [var.address_space]
}

resource "azurerm_subnet" "default" {
  name                 = "Default"
  resource_group_name  = azurerm_resource_group.site.name
  virtual_network_name = azurerm_virtual_network.site.name
  address_prefixes     = [cidrsubnet(var.address_space, 2, 0)]
}

resource "azurerm_subnet" "bastion" {
  name = "AzureBastionSubnet"
  depends_on = [
    azurerm_subnet.default
  ]
  resource_group_name  = azurerm_resource_group.site.name
  virtual_network_name = azurerm_virtual_network.site.name
  address_prefixes     = [cidrsubnet(var.address_space, 3, 6)]
}

resource "azurerm_subnet" "vpngw" {
  name = "GatewaySubnet"
  depends_on = [
    azurerm_subnet.bastion
  ]
  resource_group_name  = azurerm_resource_group.site.name
  virtual_network_name = azurerm_virtual_network.site.name
  address_prefixes     = [cidrsubnet(var.address_space, 3, 7)]
}

//==============================================================================

module "linux" {
  source              = "../linux"
  resource_group_name = azurerm_resource_group.site.name
  location            = azurerm_resource_group.site.location
  tags                = var.tags

  name           = var.name
  depends_on     = [azurerm_subnet.default]
  admin_username = var.admin_username
  subnet_id      = azurerm_subnet.default.id
  ip_address     = cidrhost(azurerm_subnet.default.address_prefixes[0], 4)
}

//==============================================================================

resource "azurerm_public_ip" "bastion" {
  name                = "${var.name}-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.site.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.site.name

  ip_configuration {
    name                 = "ipConfig1"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

//==============================================================================

resource "azurerm_public_ip" "vpngw" {
  name                = "${var.name}-vpngw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.site.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vpngw" {
  name                = "${var.name}-vpngw"
  location            = var.location
  resource_group_name = azurerm_resource_group.site.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = true
  sku           = "VpnGw1"

  ip_configuration {
    name                          = "vpngwConfig"
    public_ip_address_id          = azurerm_public_ip.vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpngw.id
  }

  bgp_settings {
    asn = var.asn
  }

  lifecycle {
    ignore_changes = [
      bgp_settings[0].peering_addresses,
    ]
  }
}
