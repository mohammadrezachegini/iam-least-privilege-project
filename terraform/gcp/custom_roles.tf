# ============================================================
# CUSTOM ROLES
# When predefined roles have too many permissions,
# create a custom role with ONLY what you need.
# This is true least privilege.
# ============================================================

resource "google_project_iam_custom_role" "app_custom_role" {
  role_id     = "${var.environment}_app_custom_role"
  title       = "App Custom Role"
  description = "Minimal permissions for app workload - only what is needed, not predefined roles"
  project     = var.project_id

  permissions = [
    "storage.objects.get",
    "storage.objects.list",
    "pubsub.topics.publish",
    "secretmanager.versions.access",
  ]
}

# Bind the custom role to the app service account
resource "google_project_iam_member" "app_sa_custom_role" {
  project = var.project_id
  role    = google_project_iam_custom_role.app_custom_role.id
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}
