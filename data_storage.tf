# --- Habilitar APIs ---
resource "google_project_service" "sqladmin" {
  project            = var.gcp_project_id
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "redis" {
  project            = var.gcp_project_id
  service            = "redis.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "pubsub" {
  project            = var.gcp_project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}
resource "google_project_service" "secretmanager" {
  project            = var.gcp_project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# --- Secret Manager para Contraseñas ---
resource "random_password" "postgres_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}
resource "google_secret_manager_secret" "postgres_db_secret" {
  project   = var.gcp_project_id
  secret_id = "postgres-db-password"
  replication { automatic = true }
  depends_on = [google_project_service.secretmanager]
}
resource "google_secret_manager_secret_version" "postgres_db_secret_version" {
  secret      = google_secret_manager_secret.postgres_db_secret.id
  secret_data = random_password.postgres_password.result
}

resource "random_password" "redis_password" {
  length  = 32
  special = false
}
resource "google_secret_manager_secret" "redis_auth_secret" {
  project   = var.gcp_project_id
  secret_id = "redis-auth-string"
  replication { automatic = true }
  depends_on = [google_project_service.secretmanager]
}
resource "google_secret_manager_secret_version" "redis_auth_secret_version" {
  secret      = google_secret_manager_secret.redis_auth_secret.id
  secret_data = random_password.redis_password.result
}

# --- Cloud SQL for PostgreSQL Instance ---
resource "google_sql_database_instance" "main_postgres_instance" {
  name             = "main-postgres-instance"
  project          = var.gcp_project_id
  region           = var.gcp_region
  database_version = var.postgres_version

  settings {
    tier              = var.postgres_tier
    availability_type = "REGIONAL" # HA

    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc_network.id
    }

    disk_autoresize = true
    disk_size       = 20
    disk_type       = "PD_SSD"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
  deletion_protection = true # Protección contra borrado accidental
  depends_on = [
    google_project_service.sqladmin,
    google_service_networking_connection.private_service_access_connection
  ]
}

resource "google_sql_database" "app_database" {
  name     = var.postgres_db_name
  project  = var.gcp_project_id
  instance = google_sql_database_instance.main_postgres_instance.name
}

resource "google_sql_user" "app_user" {
  name     = var.postgres_user_name
  project  = var.gcp_project_id
  instance = google_sql_database_instance.main_postgres_instance.name
  password = random_password.postgres_password.result
}

# --- Memorystore for Redis Instance ---
resource "google_redis_instance" "main_redis_instance" {
  name               = "main-redis-instance"
  project            = var.gcp_project_id
  tier               = var.redis_tier
  memory_size_gb     = var.redis_memory_size_gb
  location_id        = var.gcp_region
  redis_version      = var.redis_version
  authorized_network = google_compute_network.vpc_network.id
  auth_enabled       = true
  auth_string        = random_password.redis_password.result
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  deletion_protection = true # Protección contra borrado accidental

  depends_on = [
    google_project_service.redis,
    google_service_networking_connection.private_service_access_connection
  ]
}

# --- Google Cloud Pub/Sub ---
resource "google_pubsub_topic" "order_created_topic" {
  name    = "order-created-topic"
  project = var.gcp_project_id
  depends_on = [google_project_service.pubsub]
}

resource "google_pubsub_subscription" "notification_service_subscription" {
  name    = "notification-service-sub"
  project = var.gcp_project_id
  topic   = google_pubsub_topic.order_created_topic.id

  ack_deadline_seconds       = 20
  message_retention_duration = "604800s" # 7 days

  depends_on = [google_pubsub_topic.order_created_topic]
}