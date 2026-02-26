resource "hyperv_network_switch" "internal" {
  name                    = "AttackRange-${var.attack_range_id}"
  notes                   = "Attack Range internal switch for ${var.attack_range_id}"
  allow_management_os     = true
  enable_embedded_teaming = false
  enable_iov              = false
  enable_packet_direct    = false
  minimum_bandwidth_mode  = "None"
  switch_type             = "Internal"
}

resource "null_resource" "windows_nat" {
  depends_on = [hyperv_network_switch.internal]

  triggers = {
    switch_name = hyperv_network_switch.internal.name
    gateway_ip  = var.nat_gateway_ip
    subnet      = var.nat_subnet
    range_id    = var.attack_range_id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-PS
      $sw='${hyperv_network_switch.internal.name}'
      $gw='${var.nat_gateway_ip}'
      $sub='${var.nat_subnet}'
      $nat='AttackRangeNAT-${var.attack_range_id}'
      $plen=($sub -split '/')[1]
      $adapter=Get-NetAdapter|?{$_.Name -like "*$sw*"}|Select -First 1
      if(!$adapter){Write-Error "Adapter not found";exit 1}
      $existing=Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -EA SilentlyContinue
      if(!($existing|?{$_.IPAddress -eq $gw})){New-NetIPAddress -IPAddress $gw -PrefixLength $plen -InterfaceIndex $adapter.ifIndex}
      if(!(Get-NetNat -Name $nat -EA SilentlyContinue)){New-NetNat -Name $nat -InternalIPInterfaceAddressPrefix $sub}
      Write-Host "NAT $nat ready"
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = "Remove-NetNat -Name 'AttackRangeNAT-${self.triggers.range_id}' -Confirm:$false -EA SilentlyContinue"
  }
}
