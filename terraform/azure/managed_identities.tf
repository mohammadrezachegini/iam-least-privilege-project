# ============================================================
# MANAGED IDENTITIES
#
# Azure Managed Identity = AWS IAM Role = GCP Service Account
# Key advantage: Azure manages the credentials automatically.
# No secrets to rotate, no keys to store.
#
# Two types:
#   System-assigned: tied to one resource, deleted with it
#   User-assigned:   standalone, can be shared across resources
#
# We use User-assigned because it can be reused and is
# easier to manage with Terraform.
# ============================================================

# --- App Managed Identity ---
# Used by AKS pods and VMs running the application
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "${var.environment}-app-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

# --- CI/CD Service Principal ---
# Used by GitHub Actions for deployments
# Service Principal = Azure AD app registration with credentials
resource "azuread_application" "cicd_app" {
  display_name = "${var.environment}-cicd-sp"
}

resource "azuread_service_principal" "cicd_sp" {
  client_id = azuread_application.cicd_app.client_id
}

# --- Monitoring Managed Identity ---
resource "azurerm_user_assigned_identity" "monitoring_identity" {
  name                = "${var.environment}-monitoring-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}
