# ============================================================
# RBAC ASSIGNMENTS
#
# Assigning roles to identities at specific scopes.
# Scope hierarchy (narrow to broad):
#   resource > resource group > subscription > management group
#
# Rule: always assign at the NARROWEST scope possible.
# ============================================================

# --- Key Vault for app secrets ---
resource "azurerm_key_vault" "app_kv" {
  name                = "${var.environment}-app-kv-reza"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # Enable RBAC authorization instead of access policies (modern approach)
  enable_rbac_authorization = true
}

# --- Storage Account for app data ---
resource "azurerm_storage_account" "app_storage" {
  name                     = "${var.environment}appstoragereza"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App identity: read blobs from storage — scoped to storage account only
resource "azurerm_role_assignment" "app_storage_reader" {
  scope                = azurerm_storage_account.app_storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# App identity: read secrets from Key Vault — scoped to KV only
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# CI/CD SP: push images to ACR
resource "azurerm_container_registry" "acr" {
  name                = "${var.environment}acrreza"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
}

resource "azurerm_role_assignment" "cicd_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.cicd_sp.object_id
}

# Monitoring identity: read-only at resource group scope
resource "azurerm_role_assignment" "monitoring_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.monitoring_identity.principal_id
}
