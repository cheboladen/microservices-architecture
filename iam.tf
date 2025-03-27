# --- Habilitar APIs IAM ---
resource "google_project_service" "iam" {
  project            = var.gcp_project_id
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "iamcredentials" {
  project            = var.gcp_project_id
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

# --- SA para Nodos GKE ---
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "Service Account for GKE Nodes"
  project      = var.gcp_project_id
}
resource "google_project_iam_member" "gke_node_sa_monitoring" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}
resource "google_project_iam_member" "gke_node_sa_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}
resource "google_project_iam_member" "gke_node_sa_metadata" {
  project = var.gcp_project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}
resource "google_project_iam_member" "gke_node_sa_artifactregistry" {
  project = var.gcp_project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# --- SA para user-service (accede secreto DB) ---
resource "google_service_account" "user_service_sa" {
  account_id   = "user-service-sa"
  display_name = "Service Account for User Service"
  project      = var.gcp_project_id
}
resource "google_secret_manager_secret_iam_member" "user_service_sa_secret_access" {
  project   = google_secret_manager_secret.postgres_db_secret.project
  secret_id = google_secret_manager_secret.postgres_db_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.user_service_sa.email}"
}
resource "google_service_account_iam_member" "user_service_sa_workload_identity" {
  service_account_id = google_service_account.user_service_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[default/user-service]" # Asume namespace default y KSA user-service
}

# --- SA para order-service (accede secreto Redis, publica Pub/Sub) ---
resource "google_service_account" "order_service_sa" {
  account_id   = "order-service-sa"
  display_name = "Service Account for Order Service"
  project      = var.gcp_project_id
}
resource "google_pubsub_topic_iam_member" "order_service_sa_pubsub_publish" {
  project = google_pubsub_topic.order_created_topic.project
  topic   = google_pubsub_topic.order_created_topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.order_service_sa.email}"
}
resource "google_secret_manager_secret_iam_member" "order_service_sa_secret_access" {
  project   = google_secret_manager_secret.redis_auth_secret.project
  secret_id = google_secret_manager_secret.redis_auth_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.order_service_sa.email}"
}
resource "google_service_account_iam_member" "order_service_sa_workload_identity" {
  service_account_id = google_service_account.order_service_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[default/order-service]" # Asume namespace default y KSA order-service
}

# --- SA para notification-service (consume Pub/Sub) ---
resource "google_service_account" "notification_service_sa" {
  account_id   = "notification-service-sa"
  display_name = "Service Account for Notification Service"
  project      = var.gcp_project_id
}
resource "google_pubsub_subscription_iam_member" "notification_service_sa_pubsub_consume" {
  project      = google_pubsub_subscription.notification_service_subscription.project
  subscription = google_pubsub_subscription.notification_service_subscription.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.notification_service_sa.email}"
}
resource "google_service_account_iam_member" "notification_service_sa_workload_identity" {
  service_account_id = google_service_account.notification_service_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project_id}.svc.id.goog[default/notification-service]" # Asume namespace default y KSA notification-service
}