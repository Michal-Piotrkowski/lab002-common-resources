# Klucz szyfrujący dla SOPS (warunkowe tworzenie) -- na koncie Edu create_sops_key = false,
# klucz utworzony ręcznie i odczytywany przez data.azurerm_key_vault_key.sops_encryption_key
resource "azurerm_key_vault_key" "sops_encryption_key" {
  count        = var.create_sops_key ? 1 : 0
  name         = var.sops-encryption-key_name
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt"]

  depends_on = [
    azurerm_role_assignment.key_vault_crypto_officer,
    azurerm_role_assignment.sops_crypto_user,
    azurerm_role_assignment.key_vault_secrets_officer
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# Odczyt zaszyfrowanych sekretów
data "sops_file" "secrets" {
  source_file = "secrets.yaml"

  depends_on = [
    azurerm_key_vault_key.sops_encryption_key,
    azurerm_role_assignment.sops_crypto_user,
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}

# Mapowanie nazw sekretów z SOPS (podkreślniki) na nazwy w Key Vault (myślniki)
locals {
  sops_to_keyvault_mapping = {
    "devops-sp-username" = try(data.sops_file.secrets.data["devops_sp_username"], "")
    "devops-sp-password" = try(data.sops_file.secrets.data["devops_sp_password"], "")
  }
}

# Sekrety DevOps z SOPS jako źródło
resource "azurerm_key_vault_secret" "devops" {
  for_each = local.sops_to_keyvault_mapping

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.this.id

  tags = merge(local.project_tags, {
    source    = "sops"
    encrypted = "true"
  })

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    azurerm_key_vault_key.sops_encryption_key,
    azurerm_role_assignment.sops_crypto_user,
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}