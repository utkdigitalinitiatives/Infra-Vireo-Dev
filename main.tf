# Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Create a resource group
resource "azurerm_resource_group" "main" {
  name     = "rg-rocky-vm"
  location = "East US"
}

# Create a virtual network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-rocky"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Create a subnet
resource "azurerm_subnet" "internal" {
  name                 = "subnet-internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "main" {
  name                = "nsg-rocky-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create public IP
resource "azurerm_public_ip" "main" {
  name                = "pip-rocky-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Create Network Interface
resource "azurerm_network_interface" "main" {
  name                = "nic-rocky-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Accept the marketplace agreement for Rocky Linux
resource "azurerm_marketplace_agreement" "rocky" {
  publisher = "resf"
  offer     = "rockylinux-x86_64"
  plan      = "9-lvm"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-rocky-linux"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  # Disable password authentication and require SSH key
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub") # You'll need to generate this key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Rocky Linux 9 with LVM
  source_image_reference {
    publisher = "resf"
    offer     = "rockylinux-x86_64"
    sku       = "9-lvm"
    version   = "9.6.20250531"
  }

  # Plan information required for marketplace images
  plan {
    name      = "9-lvm"
    product   = "rockylinux-x86_64"
    publisher = "resf"
  }

  # Ensure marketplace agreement is accepted first
  depends_on = [azurerm_marketplace_agreement.rocky]
}

# Output the public IP address
output "public_ip_address" {
  value = azurerm_public_ip.main.ip_address
  description = "The public IP address of the VM"
}

# Output VM details for Ansible
output "vm_details" {
  value = {
    vm_name             = azurerm_linux_virtual_machine.main.name
    resource_group      = azurerm_resource_group.main.name
    public_ip          = azurerm_public_ip.main.ip_address
    private_ip         = azurerm_network_interface.main.private_ip_address
    admin_username     = azurerm_linux_virtual_machine.main.admin_username
    location           = azurerm_resource_group.main.location
    fqdn               = azurerm_public_ip.main.fqdn
  }
  description = "VM configuration details for Ansible"
}

# Output Ansible inventory format
output "ansible_inventory" {
  value = {
    all = {
      hosts = {
        "${azurerm_linux_virtual_machine.main.name}" = {
          ansible_host = azurerm_public_ip.main.ip_address
          ansible_user = azurerm_linux_virtual_machine.main.admin_username
          ansible_ssh_private_key_file = "~/.ssh/id_rsa"
          private_ip = azurerm_network_interface.main.private_ip_address
          resource_group = azurerm_resource_group.main.name
          location = azurerm_resource_group.main.location
        }
      }
    }
  }
  description = "Ansible inventory in JSON format"
}