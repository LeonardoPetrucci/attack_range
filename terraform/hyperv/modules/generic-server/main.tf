###############################################################################
# generic-server module - Hyper-V
# Creates one lab VM (Linux or Windows) on the internal switch.
# Cloud-init (Linux) or Unattend.xml (Windows) injected via NoCloud ISO.
###############################################################################

resource "hyperv_vhd" "server_disk" {
  path   = "${var.vm_base_path}/${var.server_name}-${var.attack_range_id}/disk.vhdx"
  source = var.vhdx_path
  size   = var.disk_size_gb * 1073741824
}

resource "hyperv_machine_instance" "server" {
  name                   = "ar-${var.server_name}-${var.attack_range_id}"
  generation             = 2
  processor_count        = var.cpus
  dynamic_memory         = false
  static_memory          = var.memory_mb
  automatic_start_action = "StartIfRunning"
  automatic_stop_action  = "ShutDown"
  notes                  = "Attack Range ${var.server_name} [${var.attack_range_id}]"

  network_adaptors {
    name         = "Internal"
    switch_name  = var.switch_name
    wait_for_ips = false
  }

  hard_disk_drives {
    controller_type     = "Scsi"
    controller_number   = 0
    controller_location = 0
    path                = hyperv_vhd.server_disk.path
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

###############################################################################
# Cloud-init ISO (Linux) / Unattend ISO (Windows)
###############################################################################

resource "null_resource" "cloud_init_iso" {
  triggers = {
    server_name     = var.server_name
    attack_range_id = var.attack_range_id
    windows         = tostring(var.windows)
    iso_path        = "${var.vm_base_path}/${var.server_name}-${var.attack_range_id}/cloud-init.iso"
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NonInteractive", "-Command"]
    command     = var.windows ? local.win_iso_ps : local.linux_iso_ps
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["PowerShell", "-NonInteractive", "-Command"]
    command     = "Remove-Item -Recurse -Force '${var.vm_base_path}/${self.triggers.server_name}-${self.triggers.attack_range_id}' -ErrorAction SilentlyContinue"
  }
}

###############################################################################
# PowerShell helpers stored as locals to keep provisioner blocks clean
###############################################################################

locals {
  oscdimg = "${path.module}/../../../scripts/make_iso.ps1"

  linux_iso_ps = <<-SCRIPT
$d='${var.vm_base_path}/${var.server_name}-${var.attack_range_id}'
New-Item -ItemType Directory -Force $d|Out-Null
"instance-id: ${var.server_name}-${var.attack_range_id}`nlocal-hostname: ${var.server_name}"|Set-Content "$d/meta-data" -Encoding UTF8
@"
#cloud-config
users:
  - name: ${var.user_name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    ssh_authorized_keys:
      - ${var.ssh_public_key}
write_files:
  - path: /etc/netplan/99-ar.yaml
    content: |
      network:
        version: 2
        ethernets:
          eth0:
            addresses: [${var.private_ip}/24]
            routes: [{to: 0.0.0.0/0, via: ${var.gateway_ip}}]
            nameservers: {addresses: [8.8.8.8]}
package_update: false
runcmd:
  - echo '${var.user_name}:${var.password}'|chpasswd
  - sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart sshd
  - netplan apply
"@|Set-Content "$d/user-data" -Encoding UTF8
$exe="${env:ProgramFiles(x86)}/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/amd64/Oscdimg/oscdimg.exe"
if(Test-Path $exe){& $exe -j1 -lcidata $d "$d/cloud-init.iso"}else{wsl mkisofs -output "$d/cloud-init.iso" -volid cidata -joliet -rock $d}
SCRIPT

  win_iso_ps = <<-SCRIPT
$d='${var.vm_base_path}/${var.server_name}-${var.attack_range_id}'
New-Item -ItemType Directory -Force $d|Out-Null
@"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <ComputerName>${var.server_name}</ComputerName>
    </component>
    <component name="Microsoft-Windows-TCPIP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <Interfaces>
        <Interface wcm:action="add">
          <Identifier>Ethernet</Identifier>
          <Ipv4Settings><DhcpEnabled>false</DhcpEnabled></Ipv4Settings>
          <UnicastIpAddresses><IpAddress wcm:action="add" wcm:keyValue="1">${var.private_ip}/24</IpAddress></UnicastIpAddresses>
          <Routes><Route wcm:action="add"><Identifier>0</Identifier><Prefix>0.0.0.0/0</Prefix><NextHopAddress>${var.gateway_ip}</NextHopAddress></Route></Routes>
        </Interface>
      </Interfaces>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <UserAccounts>
        <AdministratorPassword><Value>${var.password}</Value><PlainText>true</PlainText></AdministratorPassword>
      </UserAccounts>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <CommandLine>powershell -ExecutionPolicy Bypass -Command "Enable-PSRemoting -Force;Set-Item WSMan:/localhost/Service/Auth/Basic $true;Set-Item WSMan:/localhost/Service/AllowUnencrypted $true;netsh advfirewall firewall add rule name='WinRM' dir=in action=allow protocol=TCP localport=5985;Set-ItemProperty 'HKLM:/System/CurrentControlSet/Control/Terminal Server' fDenyTSConnections 0;netsh advfirewall firewall set rule group='remote desktop' new enable=Yes"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
"@|Set-Content "$d/Unattend.xml" -Encoding UTF8
$exe="${env:ProgramFiles(x86)}/Windows Kits/10/Assessment and Deployment Kit/Deployment Tools/amd64/Oscdimg/oscdimg.exe"
if(Test-Path $exe){& $exe -j1 -lcdboot $d "$d/cloud-init.iso"}else{wsl mkisofs -output "$d/cloud-init.iso" -volid CDROM -joliet -rock $d}
SCRIPT
}
