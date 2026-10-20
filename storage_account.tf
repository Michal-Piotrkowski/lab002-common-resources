resource "azurerm_storage_account" "backend" {
  name                     = local.common.st_tfs # sttfstate26<student_id>
  resource_group_name      = azurerm_resource_group.common["common"].name
  location                 = azurerm_resource_group.common["common"].location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Bezpieczeństwo
  https_traffic_only_enabled = true # wymusza HTTPS
  min_tls_version            = "TLS1_2"

  # Versioning dla historii state
  blob_properties {
    versioning_enabled       = true
    last_access_time_enabled = true # potrzebne do reguł "dni od ostatniego odczytu"

    # Soft delete jako backup (usunięte obiekty też są płatne -- krótka retencja)
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Network restrictions (opcjonalnie)
#   network_rules {
#     default_action = "Allow" # Zmień na "Deny" dla większego bezpieczeństwa
#     # ip_rules = ["YOUR_IP_ADDRESS"]
#   }

  tags = merge(local.project_tags, {
    purpose    = "tfstate"
    managed_by = "opentofu"
  })
}

resource "azurerm_storage_management_policy" "backend" {
  storage_account_id = azurerm_storage_account.backend.id

  rule {
    name    = "tfstate-tiering"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["tfstate/"]
    }

    actions {
      # Bieżący stan: Cool po 30 dniach bez odczytu (powrót do Hot przy odczycie),
      # Cold po 90 dniach bez odczytu -- zawsze dostępny online dla `tofu plan`
      base_blob {
        tier_to_cool_after_days_since_last_access_time_greater_than = 30
        auto_tier_to_hot_from_cool_enabled                          = true
        tier_to_cold_after_days_since_last_access_time_greater_than = 90
      }

      # Stare wersje: od razu Cold, po 14 dniach Archive, usunięcie po 194 dniach
      # (14 + 180 -- minimalny okres przechowywania w Archive, bez opłaty za wcześniejsze usunięcie)
      version {
        tier_to_cold_after_days_since_creation_greater_than = 0
        change_tier_to_archive_after_days_since_creation    = 14
        delete_after_days_since_creation                    = 194
      }
    }
  }
}

# RBAC - uprawnienia do Storage Account dla remote backend
resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC - uprawnienia dla Service Principal (jeśli używany)
resource "azurerm_role_assignment" "storage_blob_data_contributor_sp" {
  count                = var.sops_principal_object_id != "" ? 1 : 0
  scope                = azurerm_storage_account.backend.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.sops_principal_object_id
}


# Kontener dla state files
resource "azurerm_storage_container" "backend" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.backend.id
  container_access_type = "private"
}

output "backend_config" {
  value = {
    resource_group_name  = azurerm_resource_group.common["common"].name
    storage_account_name = azurerm_storage_account.backend.name
    container_name       = azurerm_storage_container.backend.name
  }
  description = "Backend configuration for OpenTofu"
}
