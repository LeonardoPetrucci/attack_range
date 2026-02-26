variable "enabled"         { default = false }
variable "config"          { default = null }
variable "switch_mgmt"     {}
variable "switch_ips1"     {}
variable "switch_ips2"     {}
variable "splunk_ip"       { default = "172.16.100.10" }
variable "password"        { sensitive = true }
variable "attack_range_id" { default = "" }

output "ip" { value = var.enabled ? "172.16.100.${try(var.config.ip_last_octet, 50)}" : null }

resource "null_resource" "zeek_server" {
  count = var.enabled ? 1 : 0

  triggers = {
    attack_range_id = var.attack_range_id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      $env:AR_VM_NAME    = 'ar-zeek'
      $env:AR_BOX        = '${try(var.config.box, "bento/ubuntu-22.04")}'
      $env:AR_SW_MGMT    = '${var.switch_mgmt}'
      $env:AR_SW_IPS1    = '${var.switch_ips1}'
      $env:AR_SW_IPS2    = '${var.switch_ips2}'
      $env:AR_IP_MGMT    = '172.16.100.${try(var.config.ip_last_octet, 50)}'
      $env:AR_MEMORY     = '${try(var.config.memory_mb, 4096)}'
      $env:AR_CPUS       = '${try(var.config.cpus, 2)}'
      $env:AR_OS         = 'linux'
      $env:AR_ROLE       = 'zeek'
      $env:AR_SPLUNK_IP  = '${var.splunk_ip}'
      $env:AR_PASSWORD   = '${var.password}'
      vagrant up ar-zeek --provider hyperv
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      vagrant destroy -f ar-zeek
    PS
  }
}
