# --- Habilitar API GKE ---
resource "google_project_service" "kubernetes" {
  project            = var.gcp_project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# --- Cluster GKE Regional Standard ---
resource "google_container_cluster" "main_cluster" {
  name     = "main-cluster"
  project  = var.gcp_project_id
  location = var.gcp_region

  network    = google_compute_network.vpc_network.id
  subnetwork = google_compute_subnetwork.private_subnet.id
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  ip_allocation_policy {
    cluster_secondary_range_name = google_compute_subnetwork.private_subnet.secondary_ip_range[0].range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # Mantenemos endpoint público
    master_ipv4_cidr_block  = "172.16.0.32/28" # Debe ser un /28 privado no solapado
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.master_authorized_network_cidr
      display_name = var.master_authorized_network_display_name
    }
  }

  min_master_version = var.gke_min_master_version
  release_channel {
    channel = "STABLE"
  }

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  network_policy {
    enabled = true
  }

  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Eliminar node pool por defecto para usar el nuestro gestionado
  remove_default_node_pool = true
  initial_node_count       = 1 # Requerido aunque se elimine el pool por defecto

  deletion_protection = false # Cambiar a true en producción

  depends_on = [
    google_project_service.kubernetes,
    google_service_networking_connection.private_service_access_connection
  ]
}

# --- Node Pool Gestionado (`app-nodepool`) ---
resource "google_container_node_pool" "app_nodepool" {
  name       = "app-nodepool"
  project    = var.gcp_project_id
  location   = var.gcp_region
  cluster    = google_container_cluster.main_cluster.name
  node_count = 1 # Valor inicial por zona antes de que el autoscaler actúe

  autoscaling {
    min_node_count = var.gke_node_pool_min_nodes_per_zone
    max_node_count = var.gke_node_pool_max_nodes_per_zone
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.gke_node_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"
    tags         = [var.gke_node_tag]

    # Usar la Cuenta de Servicio dedicada para nodos creada en iam.tf
    service_account = google_service_account.gke_node_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only", # Para GCR/Artifact Registry
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  depends_on = [google_container_cluster.main_cluster]
}