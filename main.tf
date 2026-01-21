# main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Random string for unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Resource Group (already works)
resource "azurerm_resource_group" "rg" {
  name     = "rg-jenkins-demo"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-jenkins-${random_string.suffix.result}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "subnet-jenkins"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group (allow SSH/RDP)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-jenkins-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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

# Public IP
resource "azurerm_public_ip" "publicip" {
  name                = "pip-jenkins-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Network Interface
resource "azurerm_network_interface" "nic" {
  name                = "nic-jenkins-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "nsga" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Virtual Machine (Ubuntu 22.04)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-jenkins-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB...ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCaC85zBvgsCLIJp+JXOrM19LNswyoxnQGSLerKSke0dKGSkUfHiwjS0PMWqK/T2nR0HAGyNvXM2y6BN8hP4KSHQdo+Mil/2UdZ3ruKdfRGgDhcYHk2oC797nzZtw4h9iRQsSg+euSPOGuWycliM9osrCBo2brzzfWs7HOpgxNXoYgXwZ6SlFZx9RigUgEBnXfUkYWyPf2ACiAIdHeQQd1Dx7YxwRGc4EPBjZFgkwE+90nmy484fSK072gjxTvz5dOGWUJx9cgXKzl/6rBZ9P9f6VSax8CREoXQXmdnDQUcmqR/brezImVQQGfz8TdafsT/ITkogbK8ktqJU+MOUkUipwtIXRi/sRqUctKdtf/rW7I3w6PS8i3lHokqy8QAKhY8le3rmWFSWbKYTrQpKk5cZ3++Rp+jOzAws8FKu7+65DrZrVHVc8X84huAjp18EqE32O4t/sVs5viqDSHaJ0P2FkSkheakseBF32UKzK5TUyW/Al44e8vEHsqw/9jdrF2Qv2GhOucHarWJdqeyAjUHXgPWFESkHwP1wqpcZwP0vPdEEqXGieGphwfmyVsY9nkeKHPWCvd1/t9wK6nJT6tsAE0A0xjQvWT2PpR4zO3tm3/T71TGe4strvKjd0C9lnkeyWZb/JGpEg2HniX8kEiSBcwnT0Q5Fw31JXD3xrsI8w== jenkins@demo"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}

# Output VM details
output "vm_public_ip" {
  value = azurerm_public_ip.publicip.ip_address
}
