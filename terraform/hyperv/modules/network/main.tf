variable "switch_wan"      { default = "CR-WAN" }
variable "switch_mgmt"     { default = "CR-MGMT" }
variable "switch_ips1"     { default = "CR-IPS1" }
variable "switch_ips2"     { default = "CR-IPS2" }
variable "nat_name"        { default = "AR-NAT" }
variable "host_wan_ip"     { default = "10.10.10.1" }
variable "host_mgmt_ip"    { default = "172.16.100.2" }
variable "attack_range_id" { default = "" }

resource "null_resource" "hyperv_network" {
  triggers = {
    switch_wan  = var.switch_wan
    switch_mgmt = var.switch_mgmt
    switch_ips1 = var.switch_ips1
    switch_ips2 = var.switch_ips2
    nat_name    = var.nat_name
  }

  provisioner "local-exec" {
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      $ErrorActionPreference = 'Stop'
      function EnsureSwitch($name) {
        if (-not (Get-VMSwitch -Name $name -EA SilentlyContinue)) {
          New-VMSwitch -Name $name -SwitchType Internal | Out-Null
          Write-Host "[+] Created vSwitch $name"
        } else { Write-Host "[=] vSwitch $name exists" }
      }
      EnsureSwitch '${var.switch_wan}'
      EnsureSwitch '${var.switch_mgmt}'
      EnsureSwitch '${var.switch_ips1}'
      EnsureSwitch '${var.switch_ips2}'

      function SetNicIP($sw, $ip, $pfx) {
        $alias = "vEthernet ($sw)"
        $ex = Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -EA SilentlyContinue | Where-Object { $_.IPAddress -eq $ip }
        if (-not $ex) {
          Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 -EA SilentlyContinue | Remove-NetIPAddress -Confirm:$false -EA SilentlyContinue
          New-NetIPAddress -InterfaceAlias $alias -IPAddress $ip -PrefixLength $pfx | Out-Null
          Write-Host "[+] Set $ip/$pfx on $alias"
        } else { Write-Host "[=] $ip on $alias exists" }
      }
      SetNicIP '${var.switch_wan}'  '${var.host_wan_ip}'  24
      SetNicIP '${var.switch_mgmt}' '${var.host_mgmt_ip}' 24

      if (-not (Get-NetNat -Name '${var.nat_name}' -EA SilentlyContinue)) {
        New-NetNat -Name '${var.nat_name}' -InternalIPInterfaceAddressPrefix '10.10.10.0/24' | Out-Null
        Write-Host "[+] Created NetNat ${var.nat_name}"
      } else { Write-Host "[=] NetNat ${var.nat_name} exists" }

      $dest = '172.16.101.0/24'
      $gw   = '172.16.100.1'
      $alias2 = "vEthernet (${var.switch_mgmt})"
      $rt = Get-NetRoute -DestinationPrefix $dest -EA SilentlyContinue | Where-Object { $_.NextHop -eq $gw }
      if (-not $rt) {
        New-NetRoute -DestinationPrefix $dest -InterfaceAlias $alias2 -NextHop $gw -RouteMetric 10 | Out-Null
        Write-Host "[+] Added route $dest via $gw"
      } else { Write-Host "[=] Route $dest exists" }
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
    command     = <<-PS
      Remove-NetNat -Name '${var.nat_name}' -Confirm:$false -EA SilentlyContinue
      Write-Host "[+] Removed NetNat ${var.nat_name}"
    PS
  }
}
