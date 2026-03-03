# ============================================================
# CUSTOM RBAC ROLES
#
# Azure has built-in roles (Owner, Contributor, Reader etc.)
# but they are often too broad. Custom roles = least privilege.
#
# Difference from AWS/GCP:
#   AWS: JSON policy with Actions + Resources
#   GCP: list of permissions in custom role
#   Azure: actions + notActions + dataActions at specific scope
# ============================================================

# --- Read-Only Custom Role ---
# Narrower than built-in "Reader" — only specific resource types
resource "azurerm_role_definition" "readonly_custom" {
  name        = "${var.environment}-readonly-custom-role"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "Read-only access scoped to specific resource types only"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.KeyVault/vaults/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}

# --- DB Admin Custom Role ---
# SQL management only — not full Contributor
resource "azurerm_role_definition" "db_admin_custom" {
  name        = "${var.environment}-db-admin-custom-role"
  scope       = "/subscriptions/${var.subscription_id}"
  description = "SQL DB management only - not full contributor access"

  permissions {
    actions = [
      "Microsoft.Sql/servers/read",
      "Microsoft.Sql/servers/databases/read",
      "Microsoft.Sql/servers/databases/write",
      "Microsoft.Sql/servers/databases/delete",
      "Microsoft.Sql/servers/firewallRules/read",
      "Microsoft.Sql/servers/firewallRules/write",
    ]
    not_actions = []
  }

  assignable_scopes = [
    "/subscriptions/${var.subscription_id}"
  ]
}
