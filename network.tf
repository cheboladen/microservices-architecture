# --- Red VPC ---
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  project                 = var.gcp_project_id
  auto_create_subnetworks = false # Modo Custom
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

# --- Subred Pública ---
resource "google_compute_subnetwork" "public_subnet" {
  name                     = var.public_subnet_name
  project                  = var.gcp_project_id
  ip_cidr_range            = var.public_subnet_cidr_block
  region                   = var.gcp_region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true
}

# --- Subred Privada ---
resource "google_compute_subnetwork" "private_subnet" {
  name                     = var.private_subnet_name
  project                  = var.gcp_project_id
  ip_cidr_range            = var.private_subnet_cidr_block # Rango primario para nodos
  region                   = var.gcp_region
  network                  = google_compute_network.vpc_network.id
  private_ip_google_access = true # Esencial para nodos privados

  secondary_ip_range {
    range_name    = var.private_subnet_pods_range_name
    ip_cidr_range = var.private_subnet_pods_cidr_block
  }
}

# --- Conexión para Servicios Gestionados (Cloud SQL, Memorystore) ---
resource "google_project_service" "servicenetworking" {
  project            = var.gcp_project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_global_address" "private_service_access_range" {
  name          = "private-service-access-range"
  project       = var.gcp_project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.private_service_access_range_prefix_length
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_service_access_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access_range.name]

  depends_on = [google_project_service.servicenetworking]
}

# --- Cloud Router (Necesario para Cloud NAT) ---
resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-router"
  project = var.gcp_project_id
  region  = var.gcp_region
  network = google_compute_network.vpc_network.id

  bgp {
    asn = 64514 # ASN Privado estándar
  }
}

# --- Cloud NAT ---
resource "google_compute_router_nat" "nat_gateway" {
  name                               = "${var.vpc_name}-nat-gateway"
  project                            = var.gcp_project_id
  router                             = google_compute_router.nat_router.name
  region                             = var.gcp_region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private_subnet.id
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "SECONDARY_IP_RANGES"] # Nodos y Pods
  }

  nat_ip_allocate_option = "AUTO_ONLY"
  enable_logging         = true
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_compute_router.nat_router]
}