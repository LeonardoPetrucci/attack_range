variable "attack_range_id" {
  type = string
}

variable "nat_subnet" {
  type    = string
  default = "10.0.2.0/24"
}

variable "nat_gateway_ip" {
  type    = string
  default = "10.0.2.1"
}
