variable "general" {
  type = object({
    attack_range_id       = string
    attack_range_password = string
    ssh_public_key        = optional(string, "")
    key_name              = optional(string, "attack_range_hyperv")
  })
}

variable "hyperv_host" {
  sensitive = true
  type = object({
    host         = string
    username     = string
    password     = string
    port         = optional(number, 5986)
    https        = optional(bool, true)
    insecure     = optional(bool, true)
    use_ntlm     = optional(bool, true)
    vm_base_path = optional(string, "C:/AttackRangeVMs")
  })
}

variable "network" {
  type = object({
    nat_subnet     = optional(string, "10.0.2.0/24")
    nat_gateway_ip = optional(string, "10.0.2.1")
    ip_prefix      = optional(string, "10.0.2")
  })
  default = {}
}

variable "router" {
  type = object({
    vhdx_path       = string
    external_switch = string
    router_ip       = string
    cpus            = optional(number, 2)
    memory_mb       = optional(number, 2048)
  })
}

variable "attack_range" {
  type = list(object({
    name          = string
    ip_last_octet = number
    vhdx_path     = string
    windows       = optional(bool, false)
    cpus          = optional(number, 2)
    memory_mb     = optional(number, 4096)
    disk_size_gb  = optional(number, 60)
    user_name     = optional(string, "ubuntu")
    ansible_roles = optional(list(any), [])
  }))
  default = []
}
