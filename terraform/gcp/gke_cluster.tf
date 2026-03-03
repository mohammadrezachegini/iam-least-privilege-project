# ============================================================
# GKE CLUSTER
# Minimal cluster for testing Workload Identity.
# Cost: ~$0.10/hr for control plane + n1-standard-1 nodes
# Run "terraform destroy" when done testing.
# ============================================================

resource "google_container_cluster" "main" {
  name     = "${var.environment}-gke-cluster"
  location = var.zone
  project  = var.project_id

  # Remove default node pool — we create our own below
  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity on the cluster
  # This is the GCP equivalent of enabling IRSA on EKS
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Disable deletion protection for easy cleanup after testing
  deletion_protection = false
}

resource "google_container_node_pool" "main" {
  name       = "${var.environment}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.main.name
  project    = var.project_id
  node_count = 1

  node_config {
    machine_type = "e2-medium"

    # CRITICAL: node pool must also have Workload Identity enabled
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

output "gke_cluster_name" {
  value = google_container_cluster.main.name
}

output "get_credentials_command" {
  description = "Run this after terraform apply to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${var.zone} --project ${var.project_id}"
}
