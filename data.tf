data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# TODO: Dodaj data source klucza SOPS gdy create_sops_key=false (krok 3)
