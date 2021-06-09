terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.58.0"
    }
  }
}

locals {}

data "azurerm_subnet" "default" {
  name                 = "Default"
  virtual_network_name = var.name
  resource_group_name  = var.name
}

resource "azurerm_public_ip" "linux" {
  for_each            = toset(var.dns_label != null ? [var.name] : [])
  name                = "${var.name}-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  allocation_method = "Static"
  domain_name_label = var.dns_label
}

resource "azurerm_network_interface" "linux" {
  name                = "${var.name}-nic"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = data.azurerm_subnet.default.id
    // private_ip_address_allocation = "Dynamic"
    // Force first usable address as we're only creating one VM per area
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(data.azurerm_subnet.default.address_prefixes[0], 4)
    public_ip_address_id          = var.dns_label != null ? azurerm_public_ip.linux[var.name].id : null
  }
}

resource "azurerm_network_interface_application_security_group_association" "linux" {
  for_each                      = toset(var.asg_id != null ? [var.name] : [])
  network_interface_id          = azurerm_network_interface.linux.id
  application_security_group_id = var.asg_id
}

resource "azurerm_linux_virtual_machine" "linux" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  computer_name                   = var.name
  admin_username                  = var.admin_username
  disable_password_authentication = true
  size                            = var.size

  network_interface_ids = [azurerm_network_interface.linux.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "${var.name}-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  // custom_data = filebase64("${path.module}/example_cloud_init")
  // custom_data = base64encode(templatefile("${path.module}/azure_arc_cloud_init.tpl", { hostname = var.name }))
  // custom_data = base64encode(data.template_cloudinit_config.multipart.rendered)

  admin_ssh_key {
    username   = var.admin_username
    public_key = length(var.admin_ssh_public_key) > 0 ? var.admin_ssh_public_key : file(var.admin_ssh_public_key_file)
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  // Confirm with Kusto query: `Heartbeat | summarize by Computer`
  name                       = "${var.name}-extension-ama"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.5"
  auto_upgrade_minor_version = true
}

resource "azurerm_virtual_machine_extension" "mma" {
  for_each                   = toset(var.workspace != null ? [var.name] : [])
  name                       = "${var.name}-extension-mma"
  virtual_machine_id         = azurerm_linux_virtual_machine.linux.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "OmsAgentForLinux"
  type_handler_version       = "1.13"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
        "workspaceId": "${var.workspace.id}"
    }
SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
        "workspaceKey": "${var.workspace.key}"
    }
PROTECTED_SETTINGS
}
