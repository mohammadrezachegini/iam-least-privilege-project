#!/bin/bash
# ============================================================
# Workload Identity Verification Script
# Same concept as verify-irsa.sh but for GCP
# ============================================================

set -e

PROJECT_ID=${1:-"***"}
CLUSTER_NAME=${2:-"dev-gke-cluster"}
ZONE=${3:-"us-central1-a"}
BUCKET_NAME=${4:-"my-app-bucket-reza-gcp"}
NAMESPACE="app"
POD_NAME="workload-identity-test-pod"

echo "================================================"
echo "  Workload Identity Verification Test"
echo "  Project: $PROJECT_ID"
echo "  Cluster: $CLUSTER_NAME"
echo "================================================"
echo ""

# Step 1: Get credentials for the cluster
echo "[1/6] Configuring kubectl..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$ZONE" --project "$PROJECT_ID"

# Step 2: Create namespace
echo "[2/6] Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Apply ServiceAccount and pod
echo "[3/6] Applying Workload Identity ServiceAccount and test pod..."
kubectl apply -f workload-identity-serviceaccount.yaml

# Step 4: Wait for pod
echo "[4/6] Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=120s

# Step 5: Check GCP identity inside the pod
echo ""
echo "[5/6] Checking GCP identity inside pod..."
echo "--- Expected: the GCP service account email, NOT your personal account ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
  gcloud auth list

# Step 6: Test GCS access if bucket provided
echo ""
if [ -n "$BUCKET_NAME" ]; then
  echo "[6/6] Testing GCS access..."
  echo "--- Listing allowed bucket (should succeed) ---"
  kubectl exec -n "$NAMESPACE" "$POD_NAME" -- \
    gsutil ls "gs://$BUCKET_NAME" && \
    echo "SUCCESS: Pod can access gs://$BUCKET_NAME" || \
    echo "FAILED: Could not access gs://$BUCKET_NAME"
else
  echo "[6/6] Skipping GCS test - no bucket provided"
  echo "      Rerun with: ./verify-workload-identity.sh $PROJECT_ID $CLUSTER_NAME $ZONE YOUR_BUCKET"
fi

echo ""
echo "================================================"
echo "  Workload Identity verification complete!"
echo "================================================"

# Cleanup
echo ""
read -p "Delete test pod? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
  echo "Test pod deleted."
fi
