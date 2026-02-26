variable "server" {
  type = object({
    name          = string
    os            = string
    box           = string
    ip_last_octet = number
    memory_mb     = optional(number, 4096)
    cpus          = optional(number, 2)
    zeek_monitor  = optional(bool, false)
    roles         = optional(list(object({
      role = string
      vars = optional(map(any), {})
    })), [])
  })
}
variable "switch_mgmt"     {}
variable "switch_ips1"     {}
variable "switch_ips2"     {}
variable "password"        { sensitive = true }
variable "attack_range_id" { default = "" }

locals {
  subnet_prefix = var.server.ip_last_octet <= 19 ? "172.16.100" : "172.16.101"
  vm_ip         = "${local.subnet_prefix}.${var.server.ip_last_octet}"
  vm_name       = "ar-${var.server.name}"
  roles_json    = jsonencode(var.server.roles)
}

output "ip" { value = local.vm_ip }

resource "null_resource" "generic_server" {
  triggers = {
    vm_name        = local.vm_name
    attack_range_id = var.attack_range_id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      $env:AR_VM_NAME      = '${local.vm_name}'
      $env:AR_BOX          = '${var.server.box}'
      $env:AR_SW_MGMT      = '${var.switch_mgmt}'
      $env:AR_SW_IPS1      = '${var.switch_ips1}'
      $env:AR_SW_IPS2      = '${var.switch_ips2}'
      $env:AR_IP_MGMT      = '${local.vm_ip}'
      $env:AR_MEMORY       = '${var.server.memory_mb}'
      $env:AR_CPUS         = '${var.server.cpus}'
      $env:AR_OS           = '${var.server.os}'
      $env:AR_ROLE         = '${var.server.name}'
      $env:AR_PASSWORD     = '${var.password}'
      $env:AR_ZEEK_MONITOR = '${var.server.zeek_monitor}'
      vagrant up '${local.vm_name}' --provider hyperv
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      vagrant destroy -f '${local.vm_name}'
    PS
  }
}
