resource "google_dns_managed_zone" "env_dns_zone" {
  name        = "${var.prefix}-zone"
  dns_name    = "${var.pcf_ert_domain}."
  description = "DNS zone (${var.pcf_ert_domain}) for the '${var.prefix}' deployment"
}

resource "google_dns_record_set" "ops-manager-dns" {
  name = "${local.opsman_dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_instance.ops-manager.network_interface.0.address}"]
}

resource "google_dns_record_set" "wildcard-sys-dns" {
  name = "*.${var.system_domain}."
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_global_address.pcf.address}"]
}

resource "google_dns_record_set" "wildcard-apps-dns" {
  name = "*.${var.apps_domain}."
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_global_address.pcf.address}"]
}

resource "google_dns_record_set" "app-ssh-dns" {
  name = "ssh.${var.system_domain}."
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_address.ssh-and-doppler.address}"]
}

resource "google_dns_record_set" "doppler-dns" {
  name = "doppler.${var.system_domain}."
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  # Smoke Test errands fail when run from control instance.
  # It appears that connection to port 443 is refused by
  # the TCP load balancer google_compute_target_pool.cf-gorouter
  # "${var.prefix}-wss-logs".
  #
  # rrdatas = ["${google_compute_address.ssh-and-doppler.address}"]
  rrdatas = ["${google_compute_global_address.pcf.address}"]
}

resource "google_dns_record_set" "loggregator-dns" {
  name = "loggregator.${var.system_domain}."
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  # Smoke Test errands fail when run from control instance.
  # It appears that connection to port 443 is refused by
  # the TCP load balancer google_compute_target_pool.cf-gorouter
  # "${var.prefix}-wss-logs".
  #
  # rrdatas = ["${google_compute_address.ssh-and-doppler.address}"]
  rrdatas = ["${google_compute_global_address.pcf.address}"]
}

resource "google_dns_record_set" "tcp-dns" {
  name = "tcp.${google_dns_managed_zone.env_dns_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = "${google_dns_managed_zone.env_dns_zone.name}"

  rrdatas = ["${google_compute_address.cf-tcp.address}"]
}
