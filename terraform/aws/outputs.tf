# ============================================================
# OUTPUTS — useful values to reference after terraform apply
# ============================================================

output "app_role_arn" {
  description = "ARN of the app role — use this in EC2 launch templates"
  value       = aws_iam_role.app_role.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD role — paste this into your GitHub Actions workflow"
  value       = aws_iam_role.cicd_role.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda role — use this when creating Lambda functions"
  value       = aws_iam_role.lambda_role.arn
}

output "readonly_role_arn" {
  description = "ARN of the read-only role — share with auditors"
  value       = aws_iam_role.readonly_role.arn
}

output "app_instance_profile_name" {
  description = "Instance profile name — use this in EC2 launch templates"
  value       = aws_iam_instance_profile.app_instance_profile.name
}

output "dev_group_name" {
  value = aws_iam_group.dev.name
}

output "ops_group_name" {
  value = aws_iam_group.ops.name
}
