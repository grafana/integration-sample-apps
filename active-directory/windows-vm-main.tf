resource "google_compute_instance" "vm_instance_public" {
  name         = "windows-active-directory-sample-app"
  machine_type = var.windows_instance_type
  zone         = var.zone
  hostname     = "windows-active-directory-vm.sampleapp.com"
  tags         = ["rdp", "http"]
  boot_disk {
    initialize_params {
      image = var.windows_2019_sku
    }
  }
  metadata = {
   sysprep-specialize-script-ps1 = templatefile("./install-ad.tp1", {
      // Variables to pass to the template
      agent_config_content     = var.agent_config_content
    }),
  }
  network_interface {
    network    = google_compute_network.vpc.name
    subnetwork = google_compute_subnetwork.network_subnet.name
    access_config {}
  }
}
