# ============================================================
# IAM POLICIES — Custom Managed Policies
# These are JSON policies stored in Terraform, NOT in the console.
# Each policy follows least privilege: only what is needed, nothing more.
# ============================================================

# --- App Policy ---
# Used by: dev group, app-role (EC2/EKS workloads)
# Allows: read app S3 bucket, read secrets
resource "aws_iam_policy" "app_policy" {
  name        = "${var.environment}-app-policy"
  path        = "/policies/"
  description = "Least-privilege policy for application workloads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppS3Bucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${var.app_s3_bucket_name}",
          "arn:aws:s3:::${var.app_s3_bucket_name}/*"
        ]
      },
      {
        Sid    = "ReadSecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Scoped to secrets with "app/" prefix only
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.environment}/app/*"
      }
    ]
  })
}

# --- CI/CD Policy ---
# Used by: cicd-role (GitHub Actions)
# Allows: push to ECR, update ECS service, read/write deploy S3 bucket
resource "aws_iam_policy" "cicd_policy" {
  name        = "${var.environment}-cicd-policy"
  path        = "/policies/"
  description = "Least-privilege policy for CI/CD pipelines (GitHub Actions)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*" # This specific action requires "*" — it is not a mistake
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        # Scoped to specific ECR repo only
        Resource = "arn:aws:ecr:${var.aws_region}:${var.account_id}:repository/${var.environment}-app"
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*" # ECS describe actions require "*" — scope with conditions in prod
      },
      {
        Sid    = "PassRoleToECS"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        # Only allow passing the specific ECS task execution role
        Resource = "arn:aws:iam::${var.account_id}:role/${var.environment}-ecs-task-execution-role"
      }
    ]
  })
}

# --- EC2 Management Policy ---
# Used by: ops group
# Allows: start/stop/describe EC2 instances (NOT create/delete — that needs admin)
resource "aws_iam_policy" "ec2_management_policy" {
  name        = "${var.environment}-ec2-management-policy"
  path        = "/policies/"
  description = "Allows ops team to manage (not create) EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Management"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:RebootInstances"
        ]
        Resource = "*"
        # Important: restrict to tagged resources only
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Environment" = var.environment
          }
        }
      }
    ]
  })
}

# --- DB Admin Policy ---
# Used by: db-admin-role
# Allows: RDS management only — not other services
resource "aws_iam_policy" "db_admin_policy" {
  name        = "${var.environment}-db-admin-policy"
  path        = "/policies/"
  description = "RDS management for database administrators"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSManagement"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ModifyDBInstance",
          "rds:RebootDBInstance",
          "rds:CreateDBSnapshot",
          "rds:RestoreDBInstanceFromDBSnapshot",
          "rds:DescribeDBSnapshots"
        ]
        Resource = "arn:aws:rds:${var.aws_region}:${var.account_id}:db:${var.environment}-*"
      }
    ]
  })
}
