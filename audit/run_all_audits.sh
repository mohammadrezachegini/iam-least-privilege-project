#!/bin/bash
# ============================================================
# Run all IAM audits across AWS, GCP, and Azure
# Used by GitHub Actions daily cron job
# ============================================================

set -e

echo "=============================================="
echo "  Multi-Cloud IAM Audit"
echo "  $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "=============================================="

FAILED=0

# Install dependencies
pip install boto3 --quiet --break-system-packages 2>/dev/null || true

# AWS Audit
echo ""
echo ">>> Running AWS IAM Audit..."
python3 aws_iam_audit.py || FAILED=1

# GCP Audit
echo ""
echo ">>> Running GCP IAM Audit..."
python3 gcp_iam_audit.py || FAILED=1

# Azure Audit
echo ""
echo ">>> Running Azure RBAC Audit..."
python3 azure_rbac_audit.py || FAILED=1

echo ""
echo "=============================================="
if [ $FAILED -eq 1 ]; then
  echo "  AUDIT FAILED: HIGH severity findings detected."
  echo "  Review the findings above and remediate."
  exit 1
else
  echo "  AUDIT PASSED: No HIGH severity findings."
  exit 0
fi
