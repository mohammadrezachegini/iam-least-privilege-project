# ============================================================
# AKS CLUSTER with Workload Identity
#
# Azure Workload Identity is the AKS equivalent of:
#   AWS IRSA / GCP Workload Identity
#
# How it works:
#   1. AKS cluster has OIDC issuer enabled
#   2. Federated credential links K8s SA to Azure Managed Identity
#   3. Pod annotated with client ID gets Azure credentials automatically
#   4. No secrets or connection strings in the pod
#
# Cost: ~$0.10/hr for AKS control plane + Standard_B2s nodes
# Run "terraform destroy" when done testing.
# ============================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.environment}-aks-cluster"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "${var.environment}-aks"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable OIDC issuer — required for Workload Identity
  oidc_issuer_enabled = true

  # Enable Workload Identity on the cluster
  workload_identity_enabled = true
}

# ============================================================
# FEDERATED CREDENTIAL
# This is the link between K8s ServiceAccount and Azure Identity
# Equivalent of:
#   AWS: trust policy on IAM role
#   GCP: workloadIdentityUser binding on service account
# ============================================================

resource "azurerm_federated_identity_credential" "app_federated" {
  name                = "${var.environment}-app-federated-credential"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.app_identity.id

  # OIDC issuer URL from the AKS cluster
  issuer = azurerm_kubernetes_cluster.main.oidc_issuer_url

  # The K8s ServiceAccount that is allowed to use this identity
  subject = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"

  audience = ["api://AzureADTokenExchange"]
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "app_identity_client_id" {
  description = "Paste this as annotation in K8s ServiceAccount yaml"
  value       = azurerm_user_assigned_identity.app_identity.client_id
}

output "get_credentials_command" {
  description = "Run this after terraform apply to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "key_vault_name" {
  value = azurerm_key_vault.app_kv.name
}

output "storage_account_name" {
  value = azurerm_storage_account.app_storage.name
}
