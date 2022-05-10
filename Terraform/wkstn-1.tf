#######
# Terraforms the first workstation = WKSTN-1
#######

#######
# Set up the NIC on the workstation and link it to our subnet
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface
#######
resource "azurerm_network_interface" "wkstn-1-nic" {
  name                = "wkstn-1-nic"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name

  ip_configuration {
    name                          = "wkstn-1-internal-ip"
    subnet_id                     = azurerm_subnet.vulnerableADLabs-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address = "10.10.10.50"

  }
}

########
# Configure the Windows wkstn-1
# Ensure that we wait for the dc to be created first
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine
########
resource "azurerm_windows_virtual_machine" "wkstn-1-vm" {
  name                = "wkstn-1"
  computer_name = var.workstation-hostname[0]
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  size                = var.workstation-size
  provision_vm_agent = true
  timezone = var.timezone
  admin_username      = var.windows-user
  admin_password      = random_password.password.result
  enable_automatic_updates = false
  

  network_interface_ids = [
    azurerm_network_interface.wkstn-1-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb = 20
  }

  source_image_reference {
    # https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-21h2-ent-g2"
    version   = "latest"
  }

  additional_unattend_content {
    content = local.autologon_data
    setting = "AutoLogon"
  }
}

########
# Setup extensions to run the provisioning script for Ansible
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_machine_extension
# https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
########
resource "azurerm_virtual_machine_extension" "provisioning-wkstn-1" {
  name = "provision-wkstn-1"
  virtual_machine_id = azurerm_windows_virtual_machine.wkstn-1-vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
  {
      "fileUris": ["https://raw.githubusercontent.com/chvancooten/CloudLabsAD/main/Terraform/files/ConfigureRemotingForAnsible.ps1"],
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
  }
  SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.wkstn-1-vm,
    azurerm_nat_gateway.ng
  ]
}