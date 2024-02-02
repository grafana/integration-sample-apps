resource "google_compute_instance" "vm_instance_public" {
  name         = "ubuntu-ibm-mq-sample-app-vm"
  machine_type = var.linux_instance_type
  zone         = var.gcp_zone
  hostname     = "cloud-vm.sample-app-ibm-mq.com"
  tags         = ["ssh", "http"]
  boot_disk {
    initialize_params {
      image        = var.ubuntu_2004_sku
    }
  }
  metadata_startup_script = templatefile("${path.module}/linux-bootstrap-script.tp1", {
    # If you have variables that you pass to the template, they go here
  })
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.network_subnet.name
    access_config {}
  }
}
