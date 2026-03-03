variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "***"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for GKE cluster"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity"
  type        = string
  default     = "app"
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name for Workload Identity"
  type        = string
  default     = "app-sa"
}
