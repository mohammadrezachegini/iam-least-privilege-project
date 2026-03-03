# ============================================================
# IRSA — IAM Roles for Service Accounts (EKS Workload Identity)
#
# How IRSA works:
#   1. EKS cluster has an OIDC provider (identity issuer URL)
#   2. You create an IAM role whose trust policy says:
#      "allow this specific Kubernetes ServiceAccount to assume me"
#   3. You annotate the K8s ServiceAccount with the role ARN
#   4. When a pod uses that ServiceAccount, AWS injects temporary
#      credentials automatically via a projected volume token
#   5. Pod can call AWS APIs — NO access keys in environment vars
# ============================================================

locals {
  # Use the cluster created in eks_cluster.tf — no data lookup needed
  oidc_issuer      = aws_eks_cluster.main.identity[0].oidc[0].issuer
  oidc_issuer_host = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
}

# ============================================================
# STEP 1 — Register the OIDC provider in IAM
# ============================================================

data "tls_certificate" "eks_oidc" {
  url = local.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = local.oidc_issuer

  tags = {
    Name = "${var.eks_cluster_name}-oidc-provider"
  }

  depends_on = [aws_eks_cluster.main]
}

# ============================================================
# STEP 2 — Create the IRSA Role
# Scoped to ONE specific Kubernetes ServiceAccount only
# ============================================================

resource "aws_iam_role" "app_irsa_role" {
  name        = "${var.environment}-app-irsa-role"
  path        = "/roles/"
  description = "Assumed by the app Kubernetes ServiceAccount via IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSServiceAccountAssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer_host}:sub" = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
            "${local.oidc_issuer_host}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_irsa_policy" {
  role       = aws_iam_role.app_irsa_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

output "app_irsa_role_arn" {
  description = "Paste this ARN into your K8s ServiceAccount annotation"
  value       = aws_iam_role.app_irsa_role.arn
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN - needed if you create more IRSA roles later"
  value       = aws_iam_openid_connect_provider.eks.arn
}
