variable "switch_wan"      {}
variable "switch_mgmt"     {}
variable "switch_ips1"     {}
variable "host_mgmt_ip"    {}
variable "subnet_mgmt"     {}
variable "subnet_targets"  {}
variable "password"        { sensitive = true }
variable "attack_range_id" { default = "" }

output "ip" { value = "172.16.100.1" }

resource "null_resource" "router_vm" {
  triggers = {
    switch_wan    = var.switch_wan
    switch_mgmt   = var.switch_mgmt
    attack_range_id = var.attack_range_id
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      $env:AR_VM_NAME    = 'ar-router'
      $env:AR_BOX        = 'bento/ubuntu-22.04'
      $env:AR_SW_MGMT    = '${var.switch_mgmt}'
      $env:AR_SW_WAN     = '${var.switch_wan}'
      $env:AR_SW_IPS1    = '${var.switch_ips1}'
      $env:AR_IP_MGMT    = '172.16.100.1'
      $env:AR_MEMORY     = '2048'
      $env:AR_CPUS       = '1'
      $env:AR_OS         = 'linux'
      $env:AR_ROLE       = 'router'
      $env:AR_PASSWORD   = '${var.password}'
      vagrant up ar-router --provider hyperv
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Set-Location "${path.module}/../../../../../vagrant"
      vagrant destroy -f ar-router
    PS
  }
}
