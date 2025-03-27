# --- Reglas Base de Firewall ---

# Permitir Conexiones Internas Básicas (ICMP, SSH Interno)
resource "google_compute_firewall" "allow_internal_base" {
  name      = "${var.vpc_name}-allow-internal-base"
  project   = var.gcp_project_id
  network   = google_compute_network.vpc_network.id
  direction = "INGRESS"
  priority  = 65534

  allow { protocol = "icmp" }
  allow { protocol = "tcp"; ports = ["22"] }

  source_ranges = [var.vpc_cidr_block]
  # Podría aplicarse a tags específicos si se desea más restricción
}

# Permitir TODO el Egress desde los nodos GKE (Simplificado - Ver README)
resource "google_compute_firewall" "allow_gke_egress_all" {
  name        = "${var.vpc_name}-allow-gke-egress-all"
  project     = var.gcp_project_id
  network     = google_compute_network.vpc_network.id
  direction   = "EGRESS"
  priority    = 1000

  allow { protocol = "all" }

  target_tags        = [var.gke_node_tag]
  destination_ranges = ["0.0.0.0/0"]
}

# --- Reglas Específicas para GKE ---

# Permitir Ingress desde Plano de Control GKE a Nodos
resource "google_compute_firewall" "allow_gke_control_plane_to_nodes" {
  name        = "${var.vpc_name}-allow-gke-cp-to-nodes"
  project     = var.gcp_project_id
  network     = google_compute_network.vpc_network.id
  direction   = "INGRESS"
  priority    = 1000

  allow { protocol = "tcp"; ports = ["10250", "443"] }
  allow { protocol = "udp"; ports = ["10250"] }

  target_tags = [var.gke_node_tag]

  # Referencia directa al CIDR del master del cluster GKE
  source_ranges = [google_container_cluster.main_cluster.private_cluster_config[0].master_ipv4_cidr_block]
}

# Permitir Ingress desde Health Checkers de GCP a Nodos
resource "google_compute_firewall" "allow_gcp_health_checks_to_nodes" {
  name        = "${var.vpc_name}-allow-gcp-health-checks"
  project     = var.gcp_project_id
  network     = google_compute_network.vpc_network.id
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    # Puertos dependen de los health checks usados por Ingress/Services GKE
    # Ejemplo común: ports = ["80", "443", "8080", "10256"] Añadir según necesidad.
  }

  target_tags   = [var.gke_node_tag]
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}

# Permitir Comunicación Pod-a-Pod y Pod-a-Servicio DENTRO del cluster
resource "google_compute_firewall" "allow_gke_internal_cluster" {
  name        = "${var.vpc_name}-allow-gke-cluster-internal"
  project     = var.gcp_project_id
  network     = google_compute_network.vpc_network.id
  direction   = "INGRESS"
  priority    = 1000

  allow { protocol = "all" } # Network Policies refinarán esto

  target_tags = [var.gke_node_tag]
  source_tags = [var.gke_node_tag] # Tráfico originado desde otros nodos GKE
  # Alternativamente, usar source_ranges con CIDRs de nodo y pod:
  # source_ranges = [var.private_subnet_cidr_block, var.private_subnet_pods_cidr_block]
}