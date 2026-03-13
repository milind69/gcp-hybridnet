# # firewall policies for two project to communicate 
# #Required 'compute.firewalls.create' permission  

# resource "google_compute_firewall" "hub-allow-internal" {
#   name    = "hub-allow-internal"
#   network = google_compute_network.hybrid-vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["10.1.1.0/24", "10.1.2.0/24"]
# }


# resource "google_compute_firewall" "spoke-allow-internal" {
#   name    = "spoke-allow-internal"
#   network = google_compute_network.hybrid-service-vpc.id
#   allow {
#     protocol = "all"
#   }
#   source_ranges = ["10.1.1.0/24", "10.1.2.0/24"]
# }
