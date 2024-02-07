resource "google_compute_instance" "vm_instance_public" {
  name         = "ubuntu-ibm-mq-sample-app-vm"
  machine_type = var.linux_instance_type
  zone         = var.gcp_zone
  hostname     = "cloud-vm.sample-app-ibm-mq.com"
  tags         = ["ssh", "http"]
  boot_disk {
    initialize_params {
      image        = var.ubuntu_2004_sku
			size         = 50
    }
  }
  metadata_startup_script = templatefile("${path.module}/linux-bootstrap-script.tp1", {
    # If you have variables that you pass to the template, they go here
		"username" = var.gcp_instance_username
  })
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.network_subnet.name
    access_config {}
  }
}
resource "google_storage_bucket" "my_bucket" {
  name          = "ibm-mq-grafana-agent-config"
  location      = "US"
  force_destroy = true  // Allows the bucket to be deleted even if it contains objects. Use with caution.
}

resource "google_storage_bucket_object" "my_object" {
  name   = "ibm-mq-grafana-agent-config"
  bucket = google_storage_bucket.my_bucket.name
  source = "./agent-config.yaml"

  // Optional: If you want to set specific storage class or ACL for the object
  storage_class = "STANDARD"
  // Set the ACL for the object if needed
}
