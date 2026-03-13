
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
