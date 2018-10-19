#-----------------------------------------------------
# Terraform Demo for MS Summit
# Based off MS examples and updated by K. Gorman
# Deploys Resources- group, vnet, VM and db
#-----------------------------------------------------


# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "73aa270e-fffd-411a-b368-b44263f61deb"
    client_id       = "a2cda0c3-c891-41de-9155-2daa7f6e7e5a"
    client_secret   = "x7M8pDCnc+5I/BxDdfbGD10F62LP/hDi+NS93UqfXfI"
    tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "summittfgroup" {
    name     = "Summit_TF_Group"
    location = "eastus"

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "summittfnetwork" {
    name                = "summitVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.summittfgroup.name}"

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "summittfsubnet" {
    name                 = "SummitSubnet"
    resource_group_name  = "${azurerm_resource_group.summittfgroup.name}"
    virtual_network_name = "${azurerm_virtual_network.summittfnetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "summittfpublicip" {
    name                         = "SummitPublicIP"
    location                     = "eastus"
    resource_group_name          = "${azurerm_resource_group.summittfgroup.name}"
    public_ip_address_allocation = "dynamic"

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "summittfnsg" {
    name                = "SummitSecurityGroup"
    location            = "eastus"
    resource_group_name = "${azurerm_resource_group.summittfgroup.name}"

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

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "summittfnic" {
    name                      = "SummitNIC"
    location                  = "eastus"
    resource_group_name       = "${azurerm_resource_group.summittfgroup.name}"
    network_security_group_id = "${azurerm_network_security_group.summitfnsg.id}"

    ip_configuration {
        name                          = "SummitNicConfiguration"
        subnet_id                     = "${azurerm_subnet.summittfsubnet.id}"
        private_ip_address_allocation = "dynamic"
        public_ip_address_id          = "${azurerm_public_ip.summittfpublicip.id}"
    }

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.summittfgroup.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "summitstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.summittfgroup.name}"
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        environment = "Terraform Summit Demo"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "summitterraformvm" {
    name                  = "summitVM"
    location              = "eastus"
    resource_group_name   = "${azurerm_resource_group.summittfgroup.name}"
    network_interface_ids = ["${azurerm_network_interface.summittfnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "summitOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "summitvm"
        admin_username = "summituser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/summituser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3Nz{snip}hwhqT9h"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.summitstorageaccount.primary_blob_endpoint}"
    }

    tags {
        environment = "Terraform Summit Demo"
    }

    resource "azure_sql_database_service" "sql-server" {
        name                 = "Summitsql1"
        database_server_name = "summitsql1"
        edition              = "Standard"
        collation            = "SQL_Latin1_General_CP1_CI_AS"
        max_size_bytes       = "5368709120"
        #service_level_id     = "f1173c43-91bd-4aaa-973c-54e79e15235b"
   }
}