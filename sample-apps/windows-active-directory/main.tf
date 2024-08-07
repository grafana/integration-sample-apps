locals {
  dc1_fqdn = "sampleappdc1.sample.local"

  dc1_prereq_ad_1 = "Import-Module ServerManager"
  dc1_prereq_ad_2 = "Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools"
  dc1_prereq_ad_3 = "Install-WindowsFeature DNS -IncludeAllSubFeature -IncludeManagementTools"
  dc1_prereq_ad_4 = "Import-Module ADDSDeployment"
  dc1_prereq_ad_5 = "Import-Module DnsServer"

  dc1_install_ad_1 = "Install-ADDSForest -DomainName ad.gpfs.net -DomainNetbiosName dnetname -DomainMode WinThreshold -ForestMode WinThreshold "
  dc1_install_ad_2 = "-DatabasePath C:/Windows/NTDS -SysvolPath C:/Windows/SYSVOL -LogPath C:/Windows/NTDS -NoRebootOnCompletion:$false -Force:$true "
  dc1_install_ad_3 = "-SafeModeAdministratorPassword (ConvertTo-SecureString AdminPassword123! -AsPlainText -Force)"

  dc1_shutdown_command = "shutdown -r -t 10"
  decode_agent_config  = "$config = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('aW50ZWdyYXRpb25zOgogIHByb21ldGhldXNfcmVtb3RlX3dyaXRlOgogIC0gYmFzaWNfYXV0aDoKICAgICAgcGFzc3dvcmQ6IHByb21wYXNzCiAgICAgIHVzZXJuYW1lOiBwcm9tdXNlcgogICAgdXJsOiBwcm9tZW5kcG9pbnQKICBhZ2VudDoKICAgIGVuYWJsZWQ6IHRydWUKICAgIHJlbGFiZWxfY29uZmlnczoKICAgIC0gYWN0aW9uOiByZXBsYWNlCiAgICAgIHNvdXJjZV9sYWJlbHM6CiAgICAgIC0gYWdlbnRfaG9zdG5hbWUKICAgICAgdGFyZ2V0X2xhYmVsOiBpbnN0YW5jZQogICAgLSBhY3Rpb246IHJlcGxhY2UKICAgICAgdGFyZ2V0X2xhYmVsOiBqb2IKICAgICAgcmVwbGFjZW1lbnQ6ICJpbnRlZ3JhdGlvbnMvYWdlbnQtY2hlY2siCiAgICBtZXRyaWNfcmVsYWJlbF9jb25maWdzOgogICAgLSBhY3Rpb246IGtlZXAKICAgICAgcmVnZXg6IChwcm9tZXRoZXVzX3RhcmdldF8uKnxwcm9tZXRoZXVzX3NkX2Rpc2NvdmVyZWRfdGFyZ2V0c3xhZ2VudF9idWlsZC4qfGFnZW50X3dhbF9zYW1wbGVzX2FwcGVuZGVkX3RvdGFsfHByb2Nlc3Nfc3RhcnRfdGltZV9zZWNvbmRzKQogICAgICBzb3VyY2VfbGFiZWxzOgogICAgICAtIF9fbmFtZV9fCiAgIyBBZGQgaGVyZSBhbnkgc25pcHBldCB0aGF0IGJlbG9uZ3MgdG8gdGhlIGBpbnRlZ3JhdGlvbnNgIHNlY3Rpb24uCiAgIyBGb3IgYSBjb3JyZWN0IGluZGVudGF0aW9uLCBwYXN0ZSBzbmlwcGV0cyBjb3BpZWQgZnJvbSBHcmFmYW5hIENsb3VkIGF0IHRoZSBiZWdpbm5pbmcgb2YgdGhlIGxpbmUuCiAgd2luZG93c19leHBvcnRlcjoKICAgIGVuYWJsZWQ6IHRydWUKICAgIGluc3RhbmNlOiAnbG9jYWxob3N0OjkxODUnICMgbXVzdCBtYXRjaCBpbnN0YW5jZSB1c2VkIGluIGxvZ3MKICAgICMgZW5hYmxlIGRlZmF1bHQgY29sbGVjdG9ycyBhbmQgdGltZSBjb2xsZWN0b3I6CiAgICBlbmFibGVkX2NvbGxlY3RvcnM6ICJhZCxjcHUsY3MsbG9naWNhbF9kaXNrLG5ldCxvcyxzZXJ2aWNlLHN5c3RlbSx0ZXh0ZmlsZSIKICAgIHJlbGFiZWxfY29uZmlnczoKICAgIC0gdGFyZ2V0X2xhYmVsOiBqb2IKICAgICAgcmVwbGFjZW1lbnQ6ICdpbnRlZ3JhdGlvbnMvd2luZG93c19leHBvcnRlcicgIyBtdXN0IG1hdGNoIGpvYiB1c2VkIGluIGxvZ3MKbG9nczoKICBjb25maWdzOgogIC0gY2xpZW50czoKICAgIC0gYmFzaWNfYXV0aDoKICAgICAgICBwYXNzd29yZDogbG9raXBhc3MKICAgICAgICB1c2VybmFtZTogbG9raXVzZXIKICAgICAgdXJsOiBsb2tpZW5kcG9pbnQKICAgIG5hbWU6IGludGVncmF0aW9ucy93aW5kb3dzCiAgICBwb3NpdGlvbnM6CiAgICAgIGZpbGVuYW1lOiAvdG1wL3Bvc2l0aW9ucy55YW1sCiAgICBzY3JhcGVfY29uZmlnczoKICAgICAgIyBBZGQgaGVyZSBhbnkgc25pcHBldCB0aGF0IGJlbG9uZ3MgdG8gdGhlIGBsb2dzLmNvbmZpZ3Muc2NyYXBlX2NvbmZpZ3NgIHNlY3Rpb24uCiAgICAgICMgRm9yIGEgY29ycmVjdCBpbmRlbnRhdGlvbiwgcGFzdGUgc25pcHBldHMgY29waWVkIGZyb20gR3JhZmFuYSBDbG91ZCBhdCB0aGUgYmVnaW5uaW5nIG9mIHRoZSBsaW5lLgogICAgLSBqb2JfbmFtZTogaW50ZWdyYXRpb25zL3dpbmRvd3MtZXhwb3J0ZXItYXBwbGljYXRpb24KICAgICAgd2luZG93c19ldmVudHM6CiAgICAgICAgdXNlX2luY29taW5nX3RpbWVzdGFtcDogdHJ1ZQogICAgICAgIGV2ZW50bG9nX25hbWU6ICdBcHBsaWNhdGlvbicKICAgICAgICBib29rbWFya19wYXRoOiAiLi9ib29rbWFya3MtYXBwLnhtbCIKICAgICAgICB4cGF0aF9xdWVyeTogJyonCiAgICAgICAgbG9jYWxlOiAxMDMzCiAgICAgICAgbGFiZWxzOgogICAgICAgICAgIGpvYjogaW50ZWdyYXRpb25zL3dpbmRvd3NfZXhwb3J0ZXIKICAgICAgICAgICBpbnN0YW5jZTogJ2xvY2FsaG9zdDo5MTg1JyAjIG11c3QgbWF0Y2ggaW5zdGFuY2UgdXNlZCBpbiB3aW5kb3dzX2V4cG9ydGVyCiAgICAgIHJlbGFiZWxfY29uZmlnczoKICAgICAgICAtIHNvdXJjZV9sYWJlbHM6IFsnY29tcHV0ZXInXQogICAgICAgICAgdGFyZ2V0X2xhYmVsOiAnYWdlbnRfaG9zdG5hbWUnCiAgICAgIHBpcGVsaW5lX3N0YWdlczoKICAgICAgICAtIGpzb246CiAgICAgICAgICAgIGV4cHJlc3Npb25zOgogICAgICAgICAgICAgIHNvdXJjZTogc291cmNlCiAgICAgICAgICAgICAgbGV2ZWw6IGxldmVsVGV4dAogICAgICAgIC0gbGFiZWxzOgogICAgICAgICAgICBzb3VyY2U6CiAgICAgICAgICAgIGxldmVsOgogICAgLSBqb2JfbmFtZTogaW50ZWdyYXRpb25zL3dpbmRvd3MtZXhwb3J0ZXItc3lzdGVtCiAgICAgIHdpbmRvd3NfZXZlbnRzOgogICAgICAgIHVzZV9pbmNvbWluZ190aW1lc3RhbXA6IHRydWUKICAgICAgICBib29rbWFya19wYXRoOiAiLi9ib29rbWFya3Mtc3lzLnhtbCIKICAgICAgICBldmVudGxvZ19uYW1lOiAiU3lzdGVtIgogICAgICAgIHhwYXRoX3F1ZXJ5OiAnKicKICAgICAgICBsb2NhbGU6IDEwMzMKICAgICAgICAjIC0gMTAzMyB0byBmb3JjZSBFbmdsaXNoIGxhbmd1YWdlCiAgICAgICAgIyAtICAwIHRvIHVzZSBkZWZhdWx0IFdpbmRvd3MgbG9jYWxlCiAgICAgICAgbGFiZWxzOgogICAgICAgICAgam9iOiBpbnRlZ3JhdGlvbnMvd2luZG93c19leHBvcnRlcgogICAgICAgICAgaW5zdGFuY2U6ICdsb2NhbGhvc3Q6OTE4NScgIyBtdXN0IG1hdGNoIGluc3RhbmNlIHVzZWQgaW4gd2luZG93c19leHBvcnRlcgogICAgICByZWxhYmVsX2NvbmZpZ3M6CiAgICAgICAgLSBzb3VyY2VfbGFiZWxzOiBbJ2NvbXB1dGVyJ10KICAgICAgICAgIHRhcmdldF9sYWJlbDogJ2FnZW50X2hvc3RuYW1lJwogICAgICBwaXBlbGluZV9zdGFnZXM6CiAgICAgICAgLSBqc29uOgogICAgICAgICAgICBleHByZXNzaW9uczoKICAgICAgICAgICAgICBzb3VyY2U6IHNvdXJjZQogICAgICAgICAgICAgIGxldmVsOiBsZXZlbFRleHQKICAgICAgICAtIGxhYmVsczoKICAgICAgICAgICAgc291cmNlOgogICAgICAgICAgICBsZXZlbDoKICAgIC0gam9iX25hbWU6IGludGVncmF0aW9ucy93aW5kb3dzLWV4cG9ydGVyLXNlY3VyaXR5CiAgICAgIHdpbmRvd3NfZXZlbnRzOgogICAgICAgIHVzZV9pbmNvbWluZ190aW1lc3RhbXA6IHRydWUKICAgICAgICBib29rbWFya19wYXRoOiAiLi9ib29rbWFya3Mtc3lzLnhtbCIKICAgICAgICBldmVudGxvZ19uYW1lOiAiU2VjdXJpdHkiCiAgICAgICAgeHBhdGhfcXVlcnk6ICcqJwogICAgICAgIGxvY2FsZTogMTAzMwogICAgICAgICMgLSAxMDMzIHRvIGZvcmNlIEVuZ2xpc2ggbGFuZ3VhZ2UKICAgICAgICAjIC0gIDAgdG8gdXNlIGRlZmF1bHQgV2luZG93cyBsb2NhbGUKICAgICAgICBsYWJlbHM6CiAgICAgICAgICBqb2I6IGludGVncmF0aW9ucy93aW5kb3dzX2V4cG9ydGVyCiAgICAgICAgICBpbnN0YW5jZTogJ2xvY2FsaG9zdDo5MTg1JyAjIG11c3QgbWF0Y2ggaW5zdGFuY2UgdXNlZCBpbiB3aW5kb3dzX2V4cG9ydGVyCiAgICAgIHJlbGFiZWxfY29uZmlnczoKICAgICAgICAtIHNvdXJjZV9sYWJlbHM6IFsnY29tcHV0ZXInXQogICAgICAgICAgdGFyZ2V0X2xhYmVsOiAnYWdlbnRfaG9zdG5hbWUnCiAgICAgIHBpcGVsaW5lX3N0YWdlczoKICAgICAgICAtIGpzb246CiAgICAgICAgICAgIGV4cHJlc3Npb25zOgogICAgICAgICAgICAgIHNvdXJjZTogc291cmNlCiAgICAgICAgICAgICAgbGV2ZWw6IGxldmVsVGV4dAogICAgICAgIC0gbGFiZWxzOgogICAgICAgICAgICBzb3VyY2U6CiAgICAgICAgICAgIGxldmVsOgptZXRyaWNzOgogIGNvbmZpZ3M6CiAgLSBuYW1lOiBpbnRlZ3JhdGlvbnMvd2luZG93c19leHBvcnRlcgogICAgcmVtb3RlX3dyaXRlOgogICAgLSBiYXNpY19hdXRoOgogICAgICAgIHBhc3N3b3JkOiBwcm9tcGFzcwogICAgICAgIHVzZXJuYW1lOiBwcm9tdXNlcgogICAgICB1cmw6IHByb21lbmRwb2ludAogICAgICAjIEFkZCBoZXJlIGFueSBzbmlwcGV0IHRoYXQgYmVsb25ncyB0byB0aGUgYG1ldHJpY3MuY29uZmlncy5zY3JhcGVfY29uZmlnc2Agc2VjdGlvbi4KICAgICAgIyBGb3IgYSBjb3JyZWN0IGluZGVudGF0aW9uLCBwYXN0ZSBzbmlwcGV0cyBjb3BpZWQgZnJvbSBHcmFmYW5hIENsb3VkIGF0IHRoZSBiZWdpbm5pbmcgb2YgdGhlIGxpbmUuCiAgZ2xvYmFsOgogICAgc2NyYXBlX2ludGVydmFsOiA2MHMKICB3YWxfZGlyZWN0b3J5OiAvdG1wL2dyYWZhbmEtYWdlbnQtd2FsCgo='))"
  write_agent_config   = "Set-Content -Path C:/agent-config.yaml -Value $config"

  grafana_prereq_1 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('promuser', '${var.prometheus_username}')} | Set-Content C:/agent-config.yaml"
  grafana_prereq_2 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('prompass', '${var.prometheus_password}')} | Set-Content C:/agent-config.yaml"
  grafana_prereq_3 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('promendpoint', '${var.prometheus_url}')} | Set-Content C:/agent-config.yaml"
  grafana_prereq_4 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('lokiuser', '${var.loki_username}')} | Set-Content C:/agent-config.yaml"
  grafana_prereq_5 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('lokipass', '${var.loki_password}')} | Set-Content C:/agent-config.yaml"
  grafana_prereq_6 = "(Get-Content C:/agent-config.yaml) | ForEach-Object { $_.Replace('lokiendpoint', '${var.loki_url}')} | Set-Content C:/agent-config.yaml"

  grafana_script_1 = "Start-BitsTransfer -Source 'https://github.com/grafana/agent/releases/download/v0.39.0/grafana-agent-windows-amd64.exe.zip' -Destination 'C:/grafana-agent-windows-amd64.exe.zip'"
  grafana_script_2 = "Expand-Archive -Path C:/grafana-agent-windows-amd64.exe.zip -DestinationPath C:/grafana-agent"

  grafana_service         = "New-Service -Name 'GrafanaAgent' -BinaryPathName 'C:/grafana-agent/grafana-agent-windows-amd64.exe --config.file=C:/agent-config.yaml' -DisplayName 'Grafana Agent Service' -Description 'This service runs the Grafana Agent' -StartupType Automatic"
  grafana_service_run     = "Start-Service -Name 'GrafanaAgent'"
  grafana_schedule_task_1 = "$Action = New-ScheduledTaskAction -Execute 'C:/grafana-agent/grafana-agent-windows-amd64.exe' -Argument '--config.file=C:/agent-config.yaml'"
  grafana_schedule_task_2 = "$Trigger = New-ScheduledTaskTrigger -AtStartup"
  grafana_schedule_task_3 = "Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName 'GrafanaAgent' -Description 'Run Grafana Agent on Startup'"
  grafana_schedule_task_4 = "Start-ScheduledTask -TaskName 'GrafanaAgent'"

  dc1_exit_code_hack     = "exit 0"
  dc1_powershell_command = "${local.decode_agent_config}; ${local.write_agent_config}; ${local.grafana_prereq_1}; ${local.grafana_prereq_2}; ${local.grafana_prereq_3}; ${local.grafana_prereq_4}; ${local.grafana_prereq_5};${local.grafana_prereq_6}; ${local.dc1_prereq_ad_1}; ${local.dc1_prereq_ad_2}; ${local.dc1_prereq_ad_3}; ${local.dc1_prereq_ad_4}; ${local.dc1_prereq_ad_5}; ${local.dc1_install_ad_1}${local.dc1_install_ad_2}${local.dc1_install_ad_3}; ${local.grafana_script_1}; ${local.grafana_script_2}; ${local.grafana_service}; ${local.grafana_service_run}; ${local.dc1_shutdown_command}; ${local.dc1_exit_code_hack};"
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "${random_pet.prefix.id}-rg"
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "${random_pet.prefix.id}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "${random_pet.prefix.id}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "${random_pet.prefix.id}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rules
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "${random_pet.prefix.id}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "${random_pet.prefix.id}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "activedirectorysample"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "main" {
  name                  = "test"
  admin_username        = "azureuser"
  admin_password        = random_password.password.result
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_DS1_v2"


  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }


  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# DC1 virtual machine extension - Install and configure AD
resource "azurerm_virtual_machine_extension" "dc1-vm-extension" {
  depends_on = [azurerm_windows_virtual_machine.main]

  name                 = "vm-active-directory"
  virtual_machine_id   = azurerm_windows_virtual_machine.main.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  settings             = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -Command \"${local.dc1_powershell_command}\""
  }
  SETTINGS

  tags = {
    application = "test_sample"
    environment = "dev"
  }
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

resource "random_password" "password" {
  length      = 20
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
  min_special = 1
  special     = true
}

resource "random_pet" "prefix" {
  prefix = var.prefix
  length = 1
}
