# ============================================================
# Packer template - Windows Server 2022 for Hyper-V
# Builds a .vhdx ready to be used by the generic-server module.
# Run: packer build packer/hyperv/windows-server-2022.pkr.hcl
# ============================================================

variable "vm_name"       { default = "win2022-ar" }
variable "output_dir"    { default = "C:/AttackRangeImages/win2022" }
variable "switch_name"   { default = "Default Switch" }
variable "iso_url"       { default = "" }  # Set to your Windows Server 2022 ISO path
variable "iso_checksum"  { default = "none" }
variable "winrm_password" { default = "Windows@Range!" }
variable "disk_size_mb"  { default = 61440 }
variable "memory_mb"     { default = 4096 }
variable "cpus"          { default = 2 }

source "hyperv-iso" "windows" {
  vm_name            = var.vm_name
  generation         = 2
  cpus               = var.cpus
  memory             = var.memory_mb
  disk_size          = var.disk_size_mb
  switch_name        = var.switch_name
  iso_url            = var.iso_url
  iso_checksum       = var.iso_checksum
  enable_secure_boot = false
  headless           = false
  output_directory   = var.output_dir

  communicator   = "winrm"
  winrm_username = "Administrator"
  winrm_password = var.winrm_password
  winrm_timeout  = "1h"

  floppy_files = ["packer/hyperv/answer_files/win2022/Autounattend.xml"]

  shutdown_command = "shutdown /s /t 10"
}

build {
  sources = ["source.hyperv-iso.windows"]

  provisioner "powershell" {
    inline = [
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "Enable-PSRemoting -Force",
      "Set-Item WSMan:/localhost/Service/Auth/Basic $true",
      "Set-Item WSMan:/localhost/Service/AllowUnencrypted $true",
      "netsh advfirewall firewall add rule name='WinRM HTTP' dir=in action=allow protocol=TCP localport=5985",
      "netsh advfirewall firewall add rule name='WinRM HTTPS' dir=in action=allow protocol=TCP localport=5986",
      "Set-ItemProperty -Path 'HKLM:/System/CurrentControlSet/Control/Terminal Server' -Name 'fDenyTSConnections' -Value 0",
      "netsh advfirewall firewall set rule group='remote desktop' new enable=Yes",
      "Install-WindowsFeature -Name 'RSAT-AD-Tools' -IncludeAllSubFeature -ErrorAction SilentlyContinue",
      "Write-Host 'Windows Server 2022 base image ready for Attack Range'"
    ]
  }

  post-processor "manifest" {
    output     = "${var.output_dir}/manifest.json"
    strip_path = true
  }
}
