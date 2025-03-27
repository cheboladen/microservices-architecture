terraform {
  # Requerir una versión de Terraform Core muy reciente y estable
  required_version = "~> 1.11.0" # Permite 1.11.x

  required_providers {
    google = {
      source  = "hashicorp/google"
      # Usar la última versión estable confirmada
      version = "~> 6.27.0" # Permite 6.27.x
    }
    random = {
      source  = "hashicorp/random"
      # Usar la última versión estable confirmada
      version = "~> 3.7.1" # Permite 3.7.x
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}