/*
Copyright 2019 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// managed certificate to use with ingress lb
resource "google_compute_managed_ssl_certificate" "managed_certificate" {
  provider = "google-beta"
  name     = "${element(split(".", var.domain),0)}"

  managed {
    domains = ["${var.domain}"]
  }
}

// public ip reserved for ingress load balancer
resource "google_compute_global_address" "ingress_ip" {
  name = "${element(split(".", var.domain),0)}"
}

// domain name to associate to ingress lb
resource "google_dns_record_set" "dns" {
  name         = "${var.domain}."
  type         = "A"
  ttl          = 300
  managed_zone = "${var.managed_zone}"

  rrdatas = ["${google_compute_global_address.ingress_ip.address}"]
}

// gke cluster
data "google_compute_zones" "available" {}

resource "google_container_cluster" "primary" {
  name               = "${var.cluster_name}"
  zone               = "${data.google_compute_zones.available.names[0]}"
  initial_node_count = 3

  additional_zones = [
    "${data.google_compute_zones.available.names[1]}",
  ]

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}
