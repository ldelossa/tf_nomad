variable "consul_token" {}

variable "ssh_key_path" {
  default = "~/.ssh/Ops-Dev.pem"
}

variable "consul_server_count" {
  default = 3
}

variable "nomad_server_count" {
  default = 3
}

variable "nomad_client_count" {
  default = 3
}

variable "cluster_name" {
  default = "test"
}

variable "instance_type" {
  default = "t2.medium"
}

variable "tag_map" {
  default = {
    "costcenter" = "Ops"
    "application" = "testing"
    "LTV-systype" = "nomad"
  }
}
