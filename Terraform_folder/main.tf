provider "azurerm" {
  subscription_id = "13e7b74b-ca4b-405f-9015-8032555cec7c"
  client_id       = "86eeda5d-4273-472a-802a-7692e14e7b6f"
  client_secret   = "CzW8Q~OJ40tbTDxrz2JDygCIX3VlFSdM0zggIcPn"
  tenant_id       = "f958e84a-92b8-439f-a62d-4f45996b6d07"
  features {}
}

#Task 1: Create a Resource Group. (Resource group already exist)
data "azurerm_resource_group" "main" {
  name     = "${var.rgname}"
}

#Task 2: Create a Virtual Network and a Subnet on the virtual network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/22"]
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                 = var.tag
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

}

#Task 3: Create a Network Security Group that allows access to other VMs on
#        a subnet and deny direct access from the internet.
resource "azurerm_network_security_group" "example" {
  name                = "${var.prefix}-NetworkSecurityGroup"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tag

  security_rule {
    name                       = "Allow-Vm-On-Subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Internet-Access"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

#Task 4: Create a Network Interface
resource "azurerm_network_interface" "main" {
  count               = var.VmSize
  name                = format("${var.prefix}-nic%s",(count.index))
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  tags                = var.tag
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

}

#Task 5: Create a Public IP
resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-PublicIpAddress"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  allocation_method   = "Static"
  tags                = var.tag
}

# Task 6: Create Load Balancer and address pool association for 
#         network interface and load balancer
resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tag

  frontend_ip_configuration {
    name                 = "IPPublic_Address"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "acctestpool"
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  count                   = var.VmSize
  ip_configuration_name   = "internal"
  network_interface_id    = azurerm_network_interface.main[count.index].id
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
}



# Task 7: Create Availabilty Set
resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-aset"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tag
}

# Task 8: Create Virtual Machines and use the image created using Packer
#         to deploy
data "azurerm_image" "main" {
  name                = "${var.Image}"
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.VmSize
  name                            = format("${var.prefix}-vm%s",(count.index))
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = data.azurerm_resource_group.main.location
  size                            = "Standard_D2s_v3"
  admin_username                  = "${var.username}"
  admin_password                  = "${var.password}"
  disable_password_authentication = false
  availability_set_id             = azurerm_availability_set.main.id
  tags                            = var.tag

  source_image_id = data.azurerm_image.main.id

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  os_disk {
    storage_account_type = var.accounttype
    caching              = "ReadWrite"
  }
  
}

# Task 9: Create Managed Disk for virtual machine
resource "azurerm_managed_disk" "main" {
  count                = var.VmSize
  name                 = format("${var.prefix}-data-disk%s",(count.index))
  resource_group_name  = data.azurerm_resource_group.main.name
  location             = data.azurerm_resource_group.main.location
  storage_account_type = var.accounttype
  create_option        = "Empty"
  disk_size_gb         = 4
  tags                 = var.tag
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  count              = var.VmSize
  managed_disk_id    = azurerm_managed_disk.main[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.main[count.index].id
  lun                = count.index
  caching            = "ReadWrite"
}