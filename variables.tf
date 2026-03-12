variable "project" {
  type = string
}

variable "region" {
  type = string
  default = "us-central1"
}   

variable "project_id" {
  type = string
}

variable "router_asn" {
    type = number
    default = 64620
}

variable "peer_asn" {
  type = number
  default = 65012
}

