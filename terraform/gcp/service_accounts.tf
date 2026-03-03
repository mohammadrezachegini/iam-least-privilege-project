# GCP SERVICE ACCOUNTS
# In GCP, service accounts are the equivalent of AWS IAM roles.

resource "google_service_account" "app_sa" {
  account_id   = "${var.environment}-app-sa"
  display_name = "App Service Account"
  description  = "Used by application workloads - least privilege"
  project      = var.project_id
}

resource "google_service_account" "cicd_sa" {
  account_id   = "${var.environment}-cicd-sa"
  display_name = "CI/CD Service Account"
  description  = "Used by CI/CD pipelines for deployments"
  project      = var.project_id
}

resource "google_service_account" "monitoring_sa" {
  account_id   = "${var.environment}-monitoring-sa"
  display_name = "Monitoring Service Account"
  description  = "Read-only access to monitoring and logging"
  project      = var.project_id
}
