variable "general" {
  type = object({
    attack_range_password = string
    attack_range_name     = string
    attack_range_id       = optional(string, "")
    cloud_provider        = string
    description           = optional(string, "")
  })
}

variable "hyperv" {
  type = object({
    switch_wan       = optional(string, "CR-WAN")
    switch_mgmt      = optional(string, "CR-MGMT")
    switch_ips1      = optional(string, "CR-IPS1")
    switch_ips2      = optional(string, "CR-IPS2")
    nat_name         = optional(string, "AR-NAT")
    host_wan_ip      = optional(string, "10.10.10.1")
    host_mgmt_ip     = optional(string, "172.16.100.2")
    subnet_mgmt      = optional(string, "172.16.100.0/24")
    subnet_targets   = optional(string, "172.16.101.0/24")
  })
  default = {}
}

variable "attack_range" {
  type = list(object({
    name           = string
    os             = string          # "linux" | "windows"
    box            = string          # Vagrant box
    ip_last_octet  = number
    memory_mb      = optional(number, 4096)
    cpus           = optional(number, 2)
    zeek           = optional(bool, false)
    zeek_monitor   = optional(bool, false)
    roles          = optional(list(object({
      role = string
      vars = optional(map(any), {})
    })), [])
  }))
  default = []
}
