#!/bin/bash
# ============================================================
# AKS Workload Identity Verification Script
# ============================================================

set -e

RESOURCE_GROUP=${1:-"dev-iam-project-rg"}
CLUSTER_NAME=${2:-"dev-aks-cluster"}
KEY_VAULT_NAME=${3:-""}
NAMESPACE="app"
POD_NAME="workload-identity-test-pod"

echo "================================================"
echo "  AKS Workload Identity Verification Test"
echo "  Cluster: $CLUSTER_NAME"
echo "  RG:      $RESOURCE_GROUP"
echo "================================================"
echo ""

# Step 1: Get credentials
echo "[1/6] Configuring kubectl..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# Step 2: Create namespace
echo "[2/6] Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Apply manifests
echo "[3/6] Applying Workload Identity ServiceAccount and test pod..."
kubectl apply -f workload-identity-serviceaccount.yaml

# Step 4: Wait for pod
echo "[4/6] Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=120s

# Step 5: Check injected env vars and Azure identity
echo ""
echo "[5/6] Checking Azure identity inside pod..."
echo "--- Checking injected Workload Identity env vars ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- env | grep -E "AZURE_CLIENT_ID|AZURE_FEDERATED_TOKEN_FILE|AZURE_TENANT_ID"

echo ""
echo "--- Checking Azure account (should show Managed Identity, not personal account) ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- az account show

# Step 6: Test Key Vault access if provided
echo ""
if [ -n "$KEY_VAULT_NAME" ]; then
  echo "[6/6] Testing Key Vault access..."
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    az keyvault secret list --vault-name "$KEY_VAULT_NAME" && \
    echo "SUCCESS: Pod can access Key Vault $KEY_VAULT_NAME" || \
    echo "FAILED: Could not access Key Vault"
else
  echo "[6/6] Skipping Key Vault test - no vault name provided"
  echo "      Rerun with: ./verify-workload-identity.sh $RESOURCE_GROUP $CLUSTER_NAME YOUR_KV_NAME"
fi

echo ""
echo "================================================"
echo "  AKS Workload Identity verification complete!"
echo "  user.type should be 'servicePrincipal' not 'user'"
echo "================================================"

read -p "Delete test pod? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
  echo "Test pod deleted."
fi
