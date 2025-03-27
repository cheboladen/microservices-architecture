output "gke_cluster_name" {
  description = "Nombre del cluster GKE creado."
  value       = google_container_cluster.main_cluster.name
}

output "gke_cluster_endpoint" {
  description = "Endpoint público del plano de control GKE (acceso restringido por redes autorizadas)."
  value       = google_container_cluster.main_cluster.endpoint
}

output "cloud_sql_postgres_connection_name" {
  description = "Nombre de conexión de la instancia Cloud SQL (para Cloud SQL Auth Proxy)."
  value       = google_sql_database_instance.main_postgres_instance.connection_name
}

output "cloud_sql_postgres_private_ip" {
  description = "Dirección IP privada de la instancia Cloud SQL."
  value       = google_sql_database_instance.main_postgres_instance.private_ip_address
  sensitive   = true
}

output "memorystore_redis_host" {
  description = "Host (IP privada) de la instancia Memorystore Redis."
  value       = google_redis_instance.main_redis_instance.host
  sensitive   = true
}

output "redis_auth_secret_id" {
  description = "ID del secreto en Secret Manager que contiene la contraseña de Redis AUTH."
  value       = google_secret_manager_secret.redis_auth_secret.secret_id
}

output "postgres_db_secret_id" {
  description = "ID del secreto en Secret Manager que contiene la contraseña del usuario de BD Postgres."
  value       = google_secret_manager_secret.postgres_db_secret.secret_id
}

output "pubsub_order_created_topic_id" {
  description = "ID del tema Pub/Sub para pedidos creados."
  value       = google_pubsub_topic.order_created_topic.id
}

output "vpc_network_name" {
  description = "Nombre de la red VPC creada."
  value       = google_compute_network.vpc_network.name
}