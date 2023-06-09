terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.56.0"
    }
    
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

locals {
  workload = "radiops789"
  location = "eastus"
  password = "P4ssw0rd#"
}

data "azuread_client_config" "current" {}


### Group ###

resource "azurerm_resource_group" "default" {
  name     = "rg${local.workload}"
  location = local.location
}

### Data Lake ###

resource "azurerm_storage_account" "lake" {
  name                     = "dls${local.workload}"
  resource_group_name      = azurerm_resource_group.default.name
  location                 = azurerm_resource_group.default.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
}

resource "azurerm_role_assignment" "adlsv2" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_client_config.current.object_id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "default" {
  name               = "data"
  storage_account_id = azurerm_storage_account.lake.id

  depends_on = [
    azurerm_role_assignment.adlsv2
  ]
}

### Databricks ###

resource "azurerm_databricks_workspace" "default" {
  name                = "dbw${local.workload}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  sku                 = "trial"
}


### Synapse ###

resource "azurerm_synapse_workspace" "default" {
  name                                 = "synw${local.workload}"
  resource_group_name                  = azurerm_resource_group.default.name
  location                             = azurerm_resource_group.default.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.default.id
  sql_administrator_login              = "sqladmin"
  sql_administrator_login_password     = local.password

  aad_admin {
    login     = "AzureAD Admin"
    object_id = data.azuread_client_config.current.object_id
    tenant_id = data.azuread_client_config.current.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }
}

# For development only
# Poduction scenarios: https://techcommunity.microsoft.com/t5/azure-synapse-analytics-blog/disabling-public-network-access-in-synapse/ba-p/3692197
resource "azurerm_synapse_firewall_rule" "allow_all" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.default.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

resource "azurerm_synapse_sql_pool" "pool1" {
  name                 = "testdb"
  synapse_workspace_id = azurerm_synapse_workspace.default.id
  sku_name             = "DW100c"
  create_mode          = "Default"
}
