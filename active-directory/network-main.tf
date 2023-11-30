
resource "google_compute_network" "vpc" {
  name                    = "bomin-terraform-vpc"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "network_subnet" {
  name          = "bomin-terraform-subnet"
  ip_cidr_range = var.network-subnet-cidr
  network       = google_compute_network.vpc.name
  region        = var.region
}

# Allow http
resource "google_compute_firewall" "allow-http" {
  name    = "bomin-terraform-fw-allow-http"
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
  name    = "bomin-terraform-fw-allow-rdp"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["rdp"]
}
