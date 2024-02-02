# Define Terraform provider
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0" # pinning version
    }
  }
}
# Define GCP provider
provider "google" {
  credentials = file(var.gcp_auth_file)
  project     = var.gcp_project
  region      = var.gcp_region
  zone        = var.gcp_zone
}
