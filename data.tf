data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

data "azurerm_key_vault_key" "sops_encryption_key" {
  count        = var.create_sops_key ? 0 : 1
  name         = var.sops-encryption-key_name
  key_vault_id = azurerm_key_vault.this.id
}
