variable "env" {
  description = "環境名"
  type        = string
  default     = "dev"
}

variable "subscription_id" {
  description = "サブスクリプションID"
  type        = string
  default     = "b17158f1-9101-4ce3-9224-19e1561bbd4b"
}

variable "location" {
  description = "Azureのリージョン"
  type        = string
  default     = "japaneast"
}

variable "resource_group_name" {
  description = "リソースグループ名"
  type        = string
  default     = "aca-appgw-rg"
}

variable "vnet_name" {
  description = "仮想ネットワーク名"
  type        = string
  default     = "aca-vnet"
}

variable "subnet_name" {
  description = "サブネット名"
  type        = string
  default     = "aca-subnet"
}

variable "vnet_address_space" {
  description = "仮想ネットワークのアドレス空間"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vm_size" {
  description = "仮想マシンのサイズ"
  type        = string
  default     = "Standard_B1s"
}

provider "azurerm" {
  features {
    # NOTE: リソースグループ内
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "rg_bastion" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_bastion.name
}

resource "azurerm_subnet" "sn_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg_bastion.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "sn_private" {
  name                 = "sn-private"
  resource_group_name  = azurerm_resource_group.rg_bastion.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "nsg_association_bastion" {
  subnet_id                 = azurerm_subnet.sn_bastion.id
  network_security_group_id = azurerm_network_security_group.nsg_bastion.id
}

resource "azurerm_subnet_network_security_group_association" "nsg_association_private" {
  subnet_id                 = azurerm_subnet.sn_private.id
  network_security_group_id = azurerm_network_security_group.nsg_private.id
}

resource "azurerm_public_ip" "bastion_ip" {
  name                = "bastion-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_bastion.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion-host"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_bastion.name
  sku                 = "Standard"
  tunneling_enabled   = true

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.sn_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
}


resource "azurerm_network_security_group" "nsg_bastion" {
  name                = "nsg-bastion"
  location            = azurerm_resource_group.rg_bastion.location
  resource_group_name = azurerm_resource_group.rg_bastion.name

  security_rule {
    name                       = "AllowGatewayInBound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowInternetInBound"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPrivateVnetOutBound"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "22"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutBound"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
}

resource "azurerm_network_security_group" "nsg_private" {
  name                = "nsg-private"
  location            = azurerm_resource_group.rg_bastion.location
  resource_group_name = azurerm_resource_group.rg_bastion.name

  security_rule {
    name                       = "AllowBastionVnetInBound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "22"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionVnetOutBound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "22"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

# ネットワークインターフェース
resource "azurerm_network_interface" "vm_nic" {
  name                = "bastion-vm-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_bastion.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sn_private.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 仮想マシン (Linux)
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "bastion-vm"
  resource_group_name = azurerm_resource_group.rg_bastion.name
  location            = var.location
  size                = var.vm_size
  computer_name       = "bastion-vm"
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.vm_nic.id
  ]

  os_disk {
    name                 = "testVmOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh_bastion.public_key_openssh
  }

  custom_data = base64encode(templatefile("${path.module}/init.sh", {}))
}

resource "tls_private_key" "ssh_bastion" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key_pem" {
  filename = "./bas_ssh_key.pem"
  content  = tls_private_key.ssh_bastion.private_key_pem
  provisioner "local-exec" {
    command = "chmod 600 ./bas_ssh_key.pem"
  }
}