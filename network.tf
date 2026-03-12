

resource "google_compute_network" "hybrid-vpc" {
  name                    = "hybrid-spoke-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "hybrid-subnet" {
  name          = "hybrid-spoke-subnet"
  ip_cidr_range = "10.1.1.0/24"
  region = var.region
  network      = google_compute_network.hybrid-vpc.id
}

resource "google_compute_network" "hybrid-service-vpc" {
  name                    = "hybrid-service-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "hybrid-service-subnet" {
  name          = "hybrid-service-subnet"
  ip_cidr_range = "10.1.2.0/24"
  region = var.region
  network      = google_compute_network.hybrid-service-vpc.id
}