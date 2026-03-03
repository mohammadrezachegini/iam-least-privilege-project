# ============================================================
# IAM GROUPS
# Rule: Always attach policies to GROUPS, never directly to users.
# Users get permissions by being added to the right group.
# ============================================================

# --- Dev Group ---
# Developers: read/write app S3, read Secrets Manager
resource "aws_iam_group" "dev" {
  name = "${var.environment}-dev-team"
  path = "/teams/"
}

resource "aws_iam_group_policy_attachment" "dev_app_policy" {
  group      = aws_iam_group.dev.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# --- Ops Group ---
# Ops team: everything dev has + EC2 and ECS management
resource "aws_iam_group" "ops" {
  name = "${var.environment}-ops-team"
  path = "/teams/"
}

resource "aws_iam_group_policy_attachment" "ops_app_policy" {
  group      = aws_iam_group.ops.name
  policy_arn = aws_iam_policy.app_policy.arn
}

resource "aws_iam_group_policy_attachment" "ops_ec2_policy" {
  group      = aws_iam_group.ops.name
  policy_arn = aws_iam_policy.ec2_management_policy.arn
}

# --- Read-Only Group ---
# Auditors: can view everything but change nothing
resource "aws_iam_group" "readonly" {
  name = "${var.environment}-readonly-team"
  path = "/teams/"
}

resource "aws_iam_group_policy_attachment" "readonly_policy" {
  group      = aws_iam_group.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess" # AWS managed policy
}

# --- Admin Group ---
# Very limited: only senior engineers + break-glass access
resource "aws_iam_group" "admin" {
  name = "${var.environment}-admin-team"
  path = "/teams/"
}

resource "aws_iam_group_policy_attachment" "admin_policy" {
  group      = aws_iam_group.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ============================================================
# EXAMPLE USERS (for testing — in real world, use SSO instead)
# ============================================================

resource "aws_iam_user" "dev_user" {
  name = "dev-user-01"
  path = "/users/"

  tags = {
    Team = "dev"
  }
}

# Add user to dev group — this is how they get permissions
resource "aws_iam_user_group_membership" "dev_user_groups" {
  user = aws_iam_user.dev_user.name

  groups = [
    aws_iam_group.dev.name,
  ]
}

resource "aws_iam_user" "readonly_user" {
  name = "auditor-01"
  path = "/users/"

  tags = {
    Team = "audit"
  }
}

resource "aws_iam_user_group_membership" "readonly_user_groups" {
  user = aws_iam_user.readonly_user.name

  groups = [
    aws_iam_group.readonly.name,
  ]
}
