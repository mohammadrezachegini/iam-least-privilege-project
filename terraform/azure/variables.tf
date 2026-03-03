variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "****"
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  default     = "*****"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "canadacentral"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for AKS Workload Identity"
  type        = string
  default     = "app"
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name for AKS Workload Identity"
  type        = string
  default     = "app-sa"
}
