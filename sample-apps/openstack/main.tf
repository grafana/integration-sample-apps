resource "google_compute_instance" "vm_instance_public" {
  name         = "openstack-sample-app-vm"
  machine_type = var.instance_type
  zone         = var.gcp_zone
  hostname     = "cloud-vm.sample-app-openstack.com"
  tags         = ["ssh", "http"]
  boot_disk {
    initialize_params {
      image = var.ubuntu_image
      size  = 50
    }
  }
  metadata_startup_script = templatefile("${path.module}/bootstrap-vm.tp1", {
    # If you have variables that you pass to the template, they go here
    "loadgen"             = var.loadgen_script
    "config"              = var.agent_config
    "loki_username"       = var.loki_username
    "loki_password"       = var.loki_password
    "loki_url"            = var.loki_url
    "prometheus_username" = var.prometheus_username
    "prometheus_password" = var.prometheus_password
    "prometheus_url"      = var.prometheus_url
  })
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.network_subnet.name
    access_config {}
  }
}
