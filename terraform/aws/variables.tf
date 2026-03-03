variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "account_id" {
  description = "Your AWS account ID (used in policy ARNs)"
  type        = string
  # Set this in terraform.tfvars — never hardcode account IDs
}

variable "app_s3_bucket_name" {
  description = "S3 bucket name that the app role can access"
  type        = string
  default     = "my-app-bucket"
}

# --- Phase 2: IRSA variables ---

variable "eks_cluster_name" {
  description = "Name of your EKS cluster"
  type        = string
  default     = "my-cluster"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where the ServiceAccount lives"
  type        = string
  default     = "app"
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name that will assume the IRSA role"
  type        = string
  default     = "app-sa"
}