# Wspólny Log Analytics workspace dla wszystkich labów (App Insights,
# Container Apps, diagnostyka VMSS). Retencja i limit chronią budżet.
# Dokładany do lab002-common-resources w Lab 5 -- pierwszym, co loguje.
variable "log_retention_days" {
  description = "Retencja logów w dniach (30 -- bez dodatkowej opłaty)"
  type        = number
  default     = 30
}

variable "log_daily_quota_gb" {
  description = "Dzienny limit ingestii logów w GB -- chroni budżet"
  type        = number
  default     = 0.2
}

resource "azurerm_log_analytics_workspace" "common" {
  name                = local.common.log
  location            = azurerm_resource_group.common["common"].location
  resource_group_name = azurerm_resource_group.common["common"].name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb

  tags = local.project_tags
}

output "log_analytics_workspace_id" {
  description = "Id wspólnego Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.common.id
}