#!/bin/bash
# ============================================================
# IRSA Verification Script
# Run this after terraform apply + kubectl apply to confirm
# the pod can access AWS without credentials.
# ============================================================

set -e

CLUSTER_NAME=${1:-"dev-eks-cluster"}
REGION=${2:-"us-east-1"}
BUCKET_NAME=${3:-"my-app-bucket-reza-aws"}
NAMESPACE="app"
POD_NAME="irsa-test-pod"

echo "================================================"
echo "  IRSA Verification Test"
echo "  Cluster: $CLUSTER_NAME"
echo "  Region:  $REGION"
echo "================================================"
echo ""

# Step 1: Update kubeconfig
echo "[1/6] Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"

# Step 2: Create namespace if it doesn't exist
echo "[2/6] Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Apply the ServiceAccount and test pod
echo "[3/6] Applying IRSA ServiceAccount and test pod..."
kubectl apply -f irsa-serviceaccount.yaml

# Step 4: Wait for pod to be running
echo "[4/6] Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/"$POD_NAME" -n "$NAMESPACE" --timeout=60s

# Step 5: Check what identity the pod is using
echo ""
echo "[5/6] Checking AWS identity inside pod..."
echo "--- Expected: the IRSA role ARN, NOT your personal credentials ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- aws sts get-caller-identity

# Step 6: Test actual S3 access
echo ""
echo "[6/6] Testing S3 access..."
echo "--- Listing allowed bucket (should succeed) ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- aws s3 ls "s3://$BUCKET_NAME" && \
  echo "SUCCESS: Pod can access s3://$BUCKET_NAME" || \
  echo "FAILED: Could not access s3://$BUCKET_NAME"

echo ""
echo "--- Listing a bucket we have NO access to (should be denied) ---"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- aws s3 ls "s3://a-bucket-we-dont-own-12345" 2>&1 | \
  grep -q "AccessDenied" && \
  echo "SUCCESS: Access correctly denied to unauthorized bucket" || \
  echo "WARNING: Unexpected result for unauthorized bucket"

echo ""
echo "================================================"
echo "  IRSA verification complete!"
echo "  If both tests passed, least privilege is working."
echo "================================================"

# Cleanup
echo ""
read -p "Delete test pod? (y/n): " confirm
if [[ "$confirm" == "y" ]]; then
  kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
  echo "Test pod deleted."
fi
