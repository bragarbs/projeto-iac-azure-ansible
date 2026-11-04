
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "eastus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-devops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-windows"
  
  # NÃO USE nomes estáticos como "rg-devops-unidade4". Use a referência abaixo:
  resource_group_name  = azurerm_resource_group.rg.name
  
  # NÃO USE "vnet-devops". Use a referência dinâmica para criar dependência automática:
  virtual_network_name = azurerm_virtual_network.vnet.name
  
  address_prefixes     = ["10.0.1.0/24"] # Ajuste conforme o seu escopo

  # Força explicitamente a criação sequencial para evitar o erro 404
  depends_on = [
    azurerm_virtual_network.vnet
  ]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-WinRM-HTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = var.allowed_source_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_source_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-windows"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size

  admin_username = var.admin_username
  admin_password = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    name                 = "disk-windows"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    
    # ALTERE APENAS ESTA LINHA:
    sku       = "2019-datacenter-gensecond"
    
    version   = "latest"
  }

  custom_data = base64encode(<<-PS
    <powershell>
    $ErrorActionPreference = "Stop"

    Install-WindowsFeature -Name Web-Server

    $cert = New-SelfSignedCertificate `
      -DnsName $env:COMPUTERNAME `
      -CertStoreLocation "Cert:\LocalMachine\My"

    $thumbprint = $cert.Thumbprint

    $securePassword = ConvertTo-SecureString `
      "${var.admin_password}" -AsPlainText -Force

    $credential = New-Object `
      System.Management.Automation.PSCredential(
        "${var.admin_username}", $securePassword
      )

    Enable-PSRemoting -Force

    winrm create winrm/config/Listener?Address=*+Transport=HTTPS `
      "@{Hostname='$env:COMPUTERNAME';CertificateThumbprint='$thumbprint'}"

    Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
    Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $false

    New-NetFirewallRule `
      -DisplayName "WinRM HTTPS 5986" `
      -Direction Inbound `
      -Protocol TCP `
      -LocalPort 5986 `
      -Action Allow

    </powershell>
  PS
  )
}
