resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}_rg"
  location = var.location
  tags = {
    env = var.tag_name
  }
}


resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}_network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]

  tags = {
    env = var.tag_name
  }
}

# Create Subnets
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  service_endpoints = [ "Microsoft.Storage" ]
  address_prefixes     = ["10.0.0.0/24"]

}

resource "azurerm_network_security_group" "nsg" {
  name = "${var.prefix}_nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location = var.location
  
  security_rule = [ 
    {
    access = "Allow"
    description = "Allow HTTP"
    destination_address_prefix = "*"
    destination_address_prefixes = []
    destination_application_security_group_ids = []
    destination_port_range = "80"
    destination_port_ranges = []
    direction = "Inbound"
    name = "Allow HTTP"
    priority = 100
    protocol = "*"
    source_address_prefix = "*"
    source_address_prefixes = []
    source_application_security_group_ids = []
    source_port_range = "*"
    source_port_ranges = []
  }

   ]

  tags = {
    env = var.tag_name
  }
}


resource "azurerm_storage_account" "storage" {
    name                        = "johndoe${var.location}storage"
    resource_group_name         = azurerm_resource_group.rg.name
    location                    = var.location
    account_replication_type    = "LRS"
    account_tier                = "Standard"
    network_rules {
      default_action = "Deny"
      virtual_network_subnet_ids = [ azurerm_subnet.subnet.id ]
    }
    tags = {
    env = var.tag_name
  }
}
resource "azurerm_subnet" "subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_public_ip" "bastion_ip" {
  name                = "${var.prefix}_bastionip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags = {
    env = var.tag_name
  }
}

resource "azurerm_bastion_host" "bastion" {
  name                = "${var.prefix}_bastionhost"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_ip.id
  }
  tags = {
    env = var.tag_name
  }
}

resource "random_string" "fqdn" {
  keepers = {
    azi_id = 1
  }
 length  = 8
 special = false
 upper   = false
 number  = false
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}_pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label = random_string.fqdn.result
  tags = {
    env = var.tag_name
  }
}


resource "azurerm_lb" "lb" {
  name                = "${var.prefix}_lb"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name


  frontend_ip_configuration {
    name                 = "${var.prefix}_configuration"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
  tags = {
    env = var.tag_name
  }
}

resource "azurerm_lb_backend_address_pool" "address_pool" {
  name                = "${var.prefix}_backend"
  loadbalancer_id     = azurerm_lb.lb.id
  
}

resource "azurerm_lb_probe" "probe" {
  name                = "${var.prefix}_probe"
  resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "tcp"
  port                = 80
  
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "${var.prefix}_http-lb-rule"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  probe_id                       = azurerm_lb_probe.probe.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.address_pool.id
  frontend_ip_configuration_name = "${var.prefix}_configuration"
  protocol                       = "Tcp"
  frontend_port                  = "80"
  backend_port                   = "80"
}

data "template_file" "cloud-init" {
  template = file("${path.module}/scripts/command.sh")
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  depends_on = [
    azurerm_lb_rule.lb_rule
  ]
  name                = "${var.prefix}_vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard_B1ms"
  instances           = 2
  admin_username      = var.username
  admin_password      = var.password
  computer_name_prefix = "${var.prefix}-vm"
  disable_password_authentication = false
  custom_data = base64encode(data.template_file.cloud-init.rendered)
  boot_diagnostics {
      storage_account_uri = azurerm_storage_account.storage.primary_blob_endpoint
    }


  source_image_reference {
        publisher = "Canonical"
        offer     = "0001-com-ubuntu-server-focal"
        sku       = "20_04-lts"
        version   = "latest"
    }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
    disk_size_gb = 32
  }

  network_interface {
    name    = "nic"
    primary = true
    network_security_group_id = azurerm_network_security_group.nsg.id

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [ azurerm_lb_backend_address_pool.address_pool.id ]
    }
  }

  tags = {
    env = var.tag_name
  }
}
