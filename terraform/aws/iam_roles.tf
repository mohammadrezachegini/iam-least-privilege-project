# ============================================================
# IAM ROLES
# Roles are assumed by services (EC2, Lambda, EKS, GitHub Actions).
# Every role has TWO parts:
#   1. Trust Policy  → WHO can assume this role
#   2. Permission Policy → WHAT they can do after assuming it
# ============================================================

# --- App Role (for EC2 instances and EKS pods) ---
resource "aws_iam_role" "app_role" {
  name        = "${var.environment}-app-role"
  path        = "/roles/"
  description = "Assumed by EC2/EKS workloads running the application"

  # Trust policy: EC2 service can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach app policy to app role
resource "aws_iam_role_policy_attachment" "app_role_policy" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Instance profile — needed to attach a role to an EC2 instance
resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.environment}-app-instance-profile"
  role = aws_iam_role.app_role.name
}

# --- CI/CD Role (assumed by GitHub Actions via OIDC) ---
# This is more secure than storing AWS keys in GitHub secrets.
# GitHub Actions gets a short-lived token via OpenID Connect.
resource "aws_iam_role" "cicd_role" {
  name        = "${var.environment}-cicd-role"
  path        = "/roles/"
  description = "Assumed by GitHub Actions for deployments (OIDC  no static keys)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDC"
        Effect = "Allow"
        Principal = {
          # This is the GitHub OIDC provider ARN — you create it once per account
          Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Only your repo can assume this role — change to your GitHub org/repo
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_role_policy" {
  role       = aws_iam_role.cicd_role.name
  policy_arn = aws_iam_policy.cicd_policy.arn
}

# --- Lambda Role ---
# Lambda functions need their own role with execute permissions
resource "aws_iam_role" "lambda_role" {
  name        = "${var.environment}-lambda-role"
  path        = "/roles/"
  description = "Assumed by Lambda functions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Lambda needs this to write CloudWatch logs — basic execution
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda also gets app permissions (read S3, read secrets)
resource "aws_iam_role_policy_attachment" "lambda_app_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# --- Read-Only Role (for auditors / external tools) ---
resource "aws_iam_role" "readonly_role" {
  name        = "${var.environment}-readonly-role"
  path        = "/roles/"
  description = "Read-only access for auditors and monitoring tools"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountUsers"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "sts:AssumeRole"
        # Require MFA to assume this role
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "readonly_role_policy" {
  role       = aws_iam_role.readonly_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# --- DB Admin Role ---
resource "aws_iam_role" "db_admin_role" {
  name        = "${var.environment}-db-admin-role"
  path        = "/roles/"
  description = "RDS management assumed by DB admins only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "db_admin_role_policy" {
  role       = aws_iam_role.db_admin_role.name
  policy_arn = aws_iam_policy.db_admin_policy.arn
}
