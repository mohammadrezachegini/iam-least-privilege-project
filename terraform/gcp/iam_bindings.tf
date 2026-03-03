# ============================================================
# IAM BINDINGS
# member + role + resource = binding
# Always bind at the LOWEST scope possible.
# ============================================================

# App SA - read GCS objects
resource "google_project_iam_member" "app_sa_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# App SA - read/write Firestore
resource "google_project_iam_member" "app_sa_datastore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# App SA - read secrets
resource "google_project_iam_member" "app_sa_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# CICD SA - push images to Artifact Registry
resource "google_project_iam_member" "cicd_sa_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# CICD SA - deploy to GKE
resource "google_project_iam_member" "cicd_sa_container_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# Monitoring SA - read monitoring data
resource "google_project_iam_member" "monitoring_sa_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

# Monitoring SA - read logs
resource "google_project_iam_member" "monitoring_sa_log_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}
