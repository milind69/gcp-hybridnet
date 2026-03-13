

resource "google_compute_network" "hybrid-vpc" {
  name                    = "hybrid-spoke-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "hybrid-subnet" {
  name          = "hybrid-spoke-subnet"
  ip_cidr_range = "10.1.1.0/24"
  region        = var.region
  network       = google_compute_network.hybrid-vpc.id
}

resource "google_compute_network" "hybrid-service-vpc" {
  name                    = "hybrid-service-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "hybrid-service-subnet" {
  name          = "hybrid-service-subnet"
  ip_cidr_range = "10.1.2.0/24"
  region        = var.region
  network       = google_compute_network.hybrid-service-vpc.id
}

resource "google_network_connectivity_hub" "ncc_hub" {
  name = "ncc-hub"

}

resource "google_network_connectivity_spoke" "hybrid_spoke" {
  name     = "hybrid-spoke"
  hub      = google_network_connectivity_hub.ncc_hub.id
  location = "global"
  linked_vpc_network {
    uri = google_compute_network.hybrid-vpc.self_link
  }
}

resource "google_network_connectivity_spoke" "hybrid_service_spoke" {
  name     = "hybrid-service-spoke"
  hub      = google_network_connectivity_hub.ncc_hub.id
  location = "global"
  linked_vpc_network {
    uri = google_compute_network.hybrid-service-vpc.self_link
  }
}

#https://docs.cloud.google.com/network-connectivity/docs/router/concepts/overview
#https://docs.cloud.google.com/network-connectivity/docs/router/concepts/bgp-route-policies-overview

resource "google_compute_router" "hybrid-router" {
  name    = "hybrid-router"
  network = google_compute_network.hybrid-vpc.id
  region  = var.region
  bgp {
    asn = var.router_asn
  }
}

resource "google_compute_router_route_policy" "prepend_on_prefix_match" {
  router = google_compute_router.hybrid-router.name
  region = var.region
  name   = "prepend-on-prefix-match"
  type   = "ROUTE_POLICY_TYPE_EXPORT"

  terms {
    priority = 100

    match {
      expression = "destination == '10.2.2.0/24'"
    }

    actions {
      expression = "asPath.prependSequence([64620, 64620, 64620, 64620, 64620])"
    }
  }

  # terms {
  #   priority = 200

  #   match {
  #     expression = true
  #   }

  #   actions {
  #     expression = "accept()"
  #   }
  # }
}
