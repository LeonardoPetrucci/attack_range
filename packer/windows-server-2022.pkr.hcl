packer {
  required_plugins {
    hyperv = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/hyperv"
    }
    vagrant = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

variable "iso_url" {
  # Scarica da: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022
  default = "./iso/WinServer2022.iso"
}
variable "iso_checksum" {
  default = "none:ignore"
}
variable "winrm_password" { default = "vagrant"; sensitive = true }

source "hyperv-iso" "win_server_2022" {
  vm_name              = "ar-win-server-2022-base"
  generation           = 2
  cpus                 = 4
  memory               = 4096
  disk_size            = 61440
  switch_name          = "CR-WAN"
  enable_secure_boot   = true
  secure_boot_template = "MicrosoftWindows"
  guest_additions_mode = "disable"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  floppy_files         = ["./answer_files/windows_server_2022/"]
  communicator         = "winrm"
  winrm_username       = "vagrant"
  winrm_password       = var.winrm_password
  winrm_use_ssl        = false
  winrm_insecure       = true
  winrm_timeout        = "6h"
  boot_wait            = "3s"
  boot_command         = ["<spacebar>"]
  shutdown_command     = "shutdown /s /t 10 /f /d p:4:1 /c \"Packer Shutdown\""
  shutdown_timeout     = "15m"
}

build {
  sources = ["source.hyperv-iso.win_server_2022"]

  provisioner "powershell" {
    inline = [
      "# Enable WinRM",
      "winrm quickconfig -q",
      "winrm set winrm/config '@{MaxTimeoutms=\"1800000\"}'",
      "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
      "winrm set winrm/config/service/auth '@{Basic=\"true\"}'",
      "winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port=\"5985\"}'",
      "netsh advfirewall firewall add rule name=\"WinRM 5985\" protocol=TCP dir=in localport=5985 action=allow",
      "sc.exe config winrm start=auto",
      "net start winrm",
      "# Vagrant user",
      "net user vagrant vagrant /add",
      "net localgroup administrators vagrant /add",
      "# Vagrant public key",
      "New-Item -ItemType Directory -Force -Path C:\\Users\\vagrant\\.ssh | Out-Null",
      "$key = (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub').Content",
      "Set-Content -Path 'C:\\Users\\vagrant\\.ssh\\authorized_keys' -Value $key"
    ]
  }

  post-processor "vagrant" {
    output               = "hyperv_win-server-2022.box"
    vagrantfile_template = "Vagrantfile.base.win"
  }
}
