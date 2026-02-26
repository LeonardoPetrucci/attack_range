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

variable "iso_url"      { default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.4-live-server-amd64.iso" }
variable "iso_checksum" { default = "file:https://releases.ubuntu.com/22.04/SHA256SUMS" }
variable "ssh_password" { default = "vagrant"; sensitive = true }

source "hyperv-iso" "ubuntu_base" {
  vm_name              = "ar-ubuntu-base"
  generation           = 2
  cpus                 = 2
  memory               = 2048
  disk_size            = 61440
  switch_name          = "CR-WAN"
  enable_secure_boot   = true
  secure_boot_template = "MicrosoftUEFICertificateAuthority"
  guest_additions_mode = "disable"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  http_directory       = "http"
  http_port_min        = 8200
  http_port_max        = 8299
  boot_wait            = "5s"
  boot_command = [
    "c<wait>",
    "linux /casper/vmlinuz autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/<enter>",
    "initrd /casper/initrd<enter>",
    "boot<enter>"
  ]
  communicator     = "ssh"
  ssh_username     = "vagrant"
  ssh_password     = var.ssh_password
  ssh_timeout      = "45m"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
}

build {
  sources = ["source.hyperv-iso.ubuntu_base"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y openssh-server python3 python3-apt",
      "sudo useradd -m -s /bin/bash vagrant || true",
      "echo 'vagrant:vagrant' | sudo chpasswd",
      "sudo mkdir -p /home/vagrant/.ssh",
      "curl -fsSL https://raw.githubusercontent.com/hashicorp/vagrant/main/keys/vagrant.pub | sudo tee /home/vagrant/.ssh/authorized_keys",
      "sudo chown -R vagrant:vagrant /home/vagrant/.ssh",
      "sudo chmod 700 /home/vagrant/.ssh && sudo chmod 600 /home/vagrant/.ssh/authorized_keys",
      "echo 'vagrant ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/vagrant",
      "sudo apt-get clean"
    ]
  }

  post-processor "vagrant" {
    output               = "hyperv_ubuntu-base.box"
    vagrantfile_template = "Vagrantfile.base"
  }
}
