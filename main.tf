terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

variable "prefix" {
  default = "test2"
}

locals {
  vm_name = "${var.prefix}-vm"
}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Interface
resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "example" {
  name                = "${local.vm_name}"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# Storage Account for Diagnostics
resource "azurerm_storage_account" "to_monitor" {
  name                     = "${var.prefix}storageacct"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Virtual Machine Extension for Diagnostics (Enable Guest Metrics)
resource "azurerm_virtual_machine_extension" "windows_diagnostics" {
  name                 = "windows-diagnostics"
  virtual_machine_id   = azurerm_windows_virtual_machine.example.id
  publisher            = "Microsoft.Azure.Diagnostics"
  type                 = "IaaSDiagnostics"
  type_handler_version = "1.5"

  settings = <<SETTINGS
  {
    "StorageAccount": "${azurerm_storage_account.to_monitor.name}",
    "WadCfg": {
      "DiagnosticMonitorConfiguration": {
        "Metrics": {
          "MetricAggregation": [
            {
              "ScheduledTransferPeriod": "PT1H"
            }
          ]
        }
      }
    }
  }
SETTINGS
}

# Monitor Diagnostic Settings (Ensure Metrics Collection)
resource "azurerm_monitor_diagnostic_setting" "example" {
  name               = "example-diagnostics"
  target_resource_id = azurerm_windows_virtual_machine.example.id
  storage_account_id = azurerm_storage_account.to_monitor.id

/*  log {
    category = "Administrative"
    enabled  = true
  }*/
  

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Action Group
resource "azurerm_monitor_action_group" "main" {
  name                = "example-actiongroup"
  resource_group_name = azurerm_resource_group.example.name
  short_name          = "exampleact"

  webhook_receiver {
    name        = "callmyapi"
    service_uri = "http://example.com/alert"
  }
}

# Metric Alert for Disk Space (Using Guest-Level Metrics)
resource "azurerm_monitor_metric_alert" "disk_space_alert" {
  name                = "disk-space-alert"
  resource_group_name = azurerm_resource_group.example.name
  scopes              = [azurerm_windows_virtual_machine.example.id]
  description         = "Alert when disk usage exceeds threshold (75%) for specific drives (C:, D:, L:, S:)"

  frequency           = "PT1H"  # 1 hour frequency
  window_size         = "PT1H"  # Set the window size equal to or greater than the frequency
  severity            = 3

  criteria {
    metric_namespace = "Microsoft.Insights/virtualMachines"
    metric_name      = "LogicalDiskFreeSpace"  # Monitor free space
    operator         = "LessThan"
    threshold        = 25  # Trigger if free space is less than 25% (75% usage)

    dimension {
      name     = "LogicalDisk"
      operator = "Include"
      values   = ["C:", "D:", "L:", "S:"]
    }

    aggregation = "Average"
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}




/*terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}


variable "prefix" {
  default = "test2"
}

locals {
  vm_name = "${var.prefix}-vm"
}

resource "azurerm_resource_group" "example" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

/*resource "azurerm_managed_disk" "example" {
  name                 = "${local.vm_name}-disk1"
  location             = azurerm_resource_group.example.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "example" {
  managed_disk_id    = azurerm_managed_disk.example.id
  virtual_machine_id = azurerm_virtual_machine.example.id
  lun                = "10"
  caching            = "ReadWrite"
}




/*--------------------------------------------------------------------------------------------===================================*/


# Storage Account (used for monitoring) 
/*
resource "azurerm_storage_account" "to_monitor" {
  name                     = "examplestorageaccount2"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}



resource "azurerm_virtual_machine_extension" "windows_diagnostics" {
  name                 = "WindowsDiagnostic"
  virtual_machine_id   = azurerm_virtual_machine.example.id
  publisher            = "Microsoft.Azure.Diagnostics"
  type                 = "IaaSDiagnostics"
  type_handler_version = "1.5"

  settings = <<SETTINGS
  {
    "StorageAccount": "${azurerm_storage_account.to_monitor.name}"
  }
SETTINGS
}




resource "azurerm_monitor_diagnostic_setting" "example" {
  name               = "example"
  target_resource_id = azurerm_virtual_machine.example.id   # Reference to VM, not Key Vault
  storage_account_id = azurerm_storage_account.to_monitor.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}





# Action Group
resource "azurerm_monitor_action_group" "main" {
  name                = "example-actiongroup"
  resource_group_name = azurerm_resource_group.example.name
  short_name          = "exampleact"

  webhook_receiver {
    name        = "callmyapi"
    service_uri = "http://example.com/alert"
  }
}

# Metric Alert for Disk Space
resource "azurerm_monitor_metric_alert" "disk_space_alert" {
  name                = "disk-space-alert"
  resource_group_name = azurerm_resource_group.example.name
  scopes              = [azurerm_virtual_machine.example.id]
  description         = "Alert when disk usage exceeds threshold (75%) for specific drives (C:, D:, L:, S:)"

  # Frequency for checking (e.g., every hour)
  frequency           = "PT1H"  # 1 hour frequency
  window_size         = "PT1H"  # Set the window size equal to or greater than the frequency
  severity            = 3

  # Criteria for each drive
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "LogicalDiskPercentFreeSpace"
    operator         = "LessThan"
    threshold        = 25  # 100% - 75% usage

    dimension {
      name     = "Drive"
      operator = "Include"
      values   = ["C:", "D:", "L:", "S:"]
    }

    aggregation = "Average"
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Diagnostic settings to ensure metrics can be displayed on the dashboard
/*resource "azurerm_monitor_diagnostic_setting" "diag" {
  name               = "diag-${azurerm_storage_account.to_monitor.name}"
  target_resource_id = azurerm_storage_account.to_monitor.id

  storage_account_id = azurerm_storage_account.to_monitor.id

  metrics {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }

  logs {
    category = "Administrative"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}
*/

