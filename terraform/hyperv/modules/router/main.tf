resource "hyperv_vhd" "router_disk" {
  path   = "${var.vm_base_path}/router-${var.attack_range_id}/router.vhdx"
  source = var.vhdx_path
  size   = 21474836480
}

resource "hyperv_machine_instance" "router" {
  name                   = "ar-router-${var.attack_range_id}"
  generation             = 2
  processor_count        = var.cpus
  dynamic_memory         = false
  static_memory          = var.memory_mb
  automatic_start_action = "StartIfRunning"
  automatic_stop_action  = "ShutDown"
  notes                  = "Attack Range WireGuard router ${var.attack_range_id}"

  network_adaptors {
    name         = "External"
    switch_name  = var.external_switch
    wait_for_ips = false
  }

  network_adaptors {
    name         = "Internal"
    switch_name  = var.internal_switch
    wait_for_ips = false
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = hyperv_vhd.router_disk.path
  }

  vm_firmware {
    enable_secure_boot   = false
    secure_boot_template = ""
  }

  vm_processor {
    expose_virtualization_extensions = false
  }

  dvd_drives {
    controller_number   = 0
    controller_location = 1
    path                = null_resource.cloud_init_iso.triggers.iso_path
  }

  depends_on = [null_resource.cloud_init_iso]
}

resource "null_resource" "cloud_init_iso" {
  triggers = {
    attack_range_id = var.attack_range_id
    iso_path        = "${var.vm_base_path}/router-${var.attack_range_id}/cloud-init.iso"
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-PS
      $dir="${var.vm_base_path}/router-${var.attack_range_id}"
      $iso="$dir/cloud-init.iso"
      New-Item -ItemType Directory -Force -Path $dir|Out-Null
      @"
instance-id: ar-router-${var.attack_range_id}
local-hostname: ar-router
"@|Set-Content "$dir/meta-data" -Encoding UTF8
      @"
#cloud-config
users:
  - name: ${var.user_name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - ${var.ssh_public_key}
package_update: false
runcmd:
  - echo '${var.user_name}:${var.password}'|chpasswd
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - ip route add ${var.internal_subnet} dev eth1
  - echo 1 > /proc/sys/net/ipv4/ip_forward
"@|Set-Content "$dir/user-data" -Encoding UTF8
      $oscdimg="${env:ProgramFiles(x86)}/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/amd64/Oscdimg/oscdimg.exe"
      if(Test-Path $oscdimg){& $oscdimg -j1 -lcidata "$dir" "$iso"}else{wsl mkisofs -output "$iso" -volid cidata -joliet -rock "$dir"}
      Write-Host "Cloud-init ISO created"
    PS
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-Command"]
    command     = "Remove-Item -Recurse -Force '${var.vm_base_path}/router-${var.attack_range_id}' -EA SilentlyContinue"
  }
}
