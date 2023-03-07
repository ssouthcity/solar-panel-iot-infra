terraform {
  cloud {
    organization = "southcity"

    workspaces {
      name = "solar-panel-cloud-azure"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

locals {
  prefix = "slrpnl"
}

resource "azurerm_resource_group" "solar" {
  name     = "${local.prefix}-resources"
  location = "West Europe"
}

resource "random_string" "storage_suffix" {
  length = 5
}

resource "azurerm_storage_account" "solar" {
  name                     = "${local.prefix}storage${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.solar.name
  location                 = azurerm_resource_group.solar.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "solar" {
  name                  = "${local.prefix}data"
  storage_account_name  = azurerm_storage_account.solar.name
  container_access_type = "private"
}

resource "azurerm_iothub" "solar" {
  name                = "${local.prefix}iothub"
  resource_group_name = azurerm_resource_group.solar.name
  location            = azurerm_resource_group.solar.location

  sku {
    name     = "S1"
    capacity = "1"
  }

  endpoint {
    type                       = "AzureIotHub.StorageContainer"
    connection_string          = azurerm_storage_account.solar.primary_blob_connection_string
    name                       = "export"
    batch_frequency_in_seconds = 60
    max_chunk_size_in_bytes    = 10485760
    container_name             = azurerm_storage_container.solar.name
    encoding                   = "Avro"
    file_name_format           = "{iothub}/{partition}_{YYYY}_{MM}_{DD}_{HH}_{mm}"
  }

  route {
    name           = "export"
    source         = "DeviceMessages"
    condition      = "true"
    endpoint_names = ["export"]
    enabled        = true
  }
}
