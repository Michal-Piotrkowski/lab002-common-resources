terraform {
  backend "azurerm" {
    resource_group_name  = local.rg.common       # rg-common-26
    storage_account_name = local.common.st_tfs   # sttfstate26<student_id>
    container_name       = "tfstate"
    key                  = "${local.year}/${var.project}/terraform.tfstate"
    use_azuread_auth     = true
  }
}