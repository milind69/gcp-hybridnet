
# https://docs.cloud.google.com/network-connectivity/docs/router/concepts/overview
# https://docs.cloud.google.com/network-connectivity/docs/router/concepts/bgp-route-policies-overview
# https://docs.cloud.google.com/network-connectivity/docs/router/reference/bgp-route-policy-reference

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

# Interconnect and Peering 

# #Ashburn IC attachment  - Note can not be done till interconnect is created for dedicated 
# resource "google_compute_interconnect_attachment" "ashburn_ica" {
#   name                     = "ashburn-ic"
#   region                   = var.region
#   type                     = "DEDICATED"
#   router                   = google_compute_router.hybrid-router.name
#   edge_availability_domain = "AVAILABILITY_DOMAIN_1"
#   bandwidth                = "BPS_10G"

# }

# #Chicago IC
# resource "google_compute_interconnect_attachment" "chicago_ica" {
#   name                     = "chicago-ic"
#   region                   = var.region
#   type                     = "DEDICATED"
#   router                   = google_compute_router.hybrid-router.name
#   edge_availability_domain = "AVAILABILITY_DOMAIN_2"
#   bandwidth                = "BPS_10G"

# }
# # Router Interfaces 

# resource "google_compute_router_interface" "router-ashburn-interface-01" {
#   name                    = "router-ashburn-interface-01"
#   router                  = google_compute_router.hybrid-router.name
#   region                  = var.region
#   ip_range                = "169.254.10.1/30"
#   interconnect_attachment = google_compute_interconnect_attachment.ashburn_ic.name
# }

# resource "google_compute_router_interface" "router-chicago-interface-01" {
#   name                    = "router-chicago-interface-01"
#   router                  = google_compute_router.hybrid-router.name
#   region                  = var.region
#   ip_range                = "169.254.10.1/30"
#   interconnect_attachment = google_compute_interconnect_attachment.chicago_ic.name
# }

# #BGP Peering 

# resource "google_compute_router_peer" "ashburn-peer" {
#   name            = "ashburn-peer"
#   router          = google_compute_router.hybrid-router.name
#   region          = var.region
#   peer_asn        = var.peer_asn
#   interface       = google_compute_router_interface.router-ashburn-interface-01.name
#   peer_ip_address = "169.254.10.2"
#   export_policies = [google_compute_router_route_policy.prepend_on_prefix_match.name]

# }

# resource "google_compute_router_peer" "chicago-peer" {
#   name            = "chicago-peer"
#   router          = google_compute_router.hybrid-router.name
#   region          = var.region
#   peer_asn        = var.peer_asn
#   interface       = google_compute_router_interface.router-chicago-interface-01.name
#   peer_ip_address = "169.254.20.2"
#   export_policies = [google_compute_router_route_policy.prepend_on_prefix_match.name]
# }

