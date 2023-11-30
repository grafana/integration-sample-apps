resource "google_compute_network" "vpc" {
  name                    = "active-directory-sample-app-terraform-vpc"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "network_subnet" {
  name          = "active-directory-sample-app-subnet"
  ip_cidr_range = var.network-subnet-cidr
  network       = google_compute_network.vpc.name
  region        = var.region
}

# Allow http
resource "google_compute_firewall" "allow-http" {
  name    = "active-directory-sample-app-fw-allow-http"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http"]
}

# allow rdp
resource "google_compute_firewall" "allow-rdp" {
  name    = "active-directory-sample-app-fw-allow-rdp"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["rdp"]
}
