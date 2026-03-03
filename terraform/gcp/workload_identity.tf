resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
  ]
  depends_on = [google_container_cluster.main]
}
output "workload_identity_annotation" {
  description = "Add this annotation to your K8s ServiceAccount yaml"
  value       = "iam.gke.io/gcp-service-account: ${google_service_account.app_sa.email}"
}
output "app_sa_email" { value = google_service_account.app_sa.email }
output "cicd_sa_email" { value = google_service_account.cicd_sa.email }
