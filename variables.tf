variable "gcp_project_id" {
  description = "El ID del proyecto GCP donde se desplegará la infraestructura."
  type        = string
  # No default - debe ser proporcionado
}

variable "gcp_region" {
  description = "La región GCP para los recursos regionales."
  type        = string
  default     = "europe-southwest1"
}

variable "vpc_name" {
  description = "Nombre para la red VPC."
  type        = string
  default     = "main-vpc"
}

variable "public_subnet_name" {
  description = "Nombre para la subred pública."
  type        = string
  default     = "public-subnet-madrid"
}

variable "private_subnet_name" {
  description = "Nombre para la subred privada."
  type        = string
  default     = "private-subnet-madrid"
}

variable "private_subnet_pods_range_name" {
  description = "Nombre del rango secundario para Pods en la subred privada."
  type        = string
  default     = "private-subnet-pods-madrid"
}

variable "vpc_cidr_block" {
  description = "Rango IP principal para la VPC."
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidr_block" {
  description = "Rango IP para la subred pública."
  type        = string
  default     = "10.10.1.0/24"
}

variable "private_subnet_cidr_block" {
  description = "Rango IP principal (nodos) para la subred privada."
  type        = string
  default     = "10.10.2.0/24"
}

variable "private_subnet_pods_cidr_block" {
  description = "Rango IP secundario (pods) para la subred privada."
  type        = string
  default     = "10.11.0.0/20"
}

variable "private_service_access_range_prefix_length" {
  description = "Tamaño del prefijo para el rango reservado para Private Service Access."
  type        = number
  default     = 16 # /16
}

variable "master_authorized_network_cidr" {
  description = "CIDR de la red autorizada para acceder al master GKE."
  type        = string
  default     = "215.215.0.0/16"
}

variable "master_authorized_network_display_name" {
  description = "Nombre descriptivo para la red autorizada."
  type        = string
  default     = "CorporateNetwork"
}

variable "gke_node_tag" {
  description = "Etiqueta de red para aplicar a los nodos GKE."
  type        = string
  default     = "gke-node"
}

variable "gke_min_master_version" {
  description = "Versión mínima deseada para el master GKE (del canal estable)."
  type        = string
  default     = "1.31"
}

variable "gke_node_machine_type" {
  description = "Tipo de máquina para los nodos GKE."
  type        = string
  default     = "e2-medium"
}

variable "gke_node_pool_min_nodes_per_zone" {
  description = "Número mínimo de nodos por zona en el node pool."
  type        = number
  default     = 1
}

variable "gke_node_pool_max_nodes_per_zone" {
  description = "Número máximo de nodos por zona en el node pool."
  type        = number
  default     = 3
}

variable "postgres_version" {
  description = "Versión de PostgreSQL para Cloud SQL."
  type        = string
  default     = "POSTGRES_15"
}

variable "postgres_tier" {
  description = "Tier (tamaño) de la instancia Cloud SQL."
  type        = string
  default     = "db-f1-micro"
}

variable "postgres_db_name" {
  description = "Nombre de la base de datos inicial en Cloud SQL."
  type        = string
  default     = "app_db"
}

variable "postgres_user_name" {
  description = "Nombre del usuario de aplicación en Cloud SQL."
  type        = string
  default     = "app_user"
}

variable "redis_version" {
  description = "Versión de Redis para Memorystore."
  type        = string
  default     = "REDIS_7_0"
}

variable "redis_tier" {
  description = "Tier (HA o Basic) para Memorystore."
  type        = string
  default     = "STANDARD_HA" # STANDARD_HA o BASIC
}

variable "redis_memory_size_gb" {
  description = "Tamaño de memoria en GB para la instancia Redis."
  type        = number
  default     = 1
}