# ============================================================
# Packer template - Ubuntu 22.04 LTS for Hyper-V
# Builds a .vhdx ready to be used by the generic-server module.
# Run: packer build packer/hyperv/ubuntu-22.04.pkr.hcl
# ============================================================

variable "vm_name"        { default = "ubuntu-22.04-ar" }
variable "output_dir"     { default = "C:/AttackRangeImages/ubuntu-22.04" }
variable "switch_name"    { default = "Default Switch" }
variable "iso_url"        { default = "https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso" }
variable "iso_checksum"   { default = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0" }
variable "ssh_password"   { default = "Ubuntu@Range!" }
variable "disk_size_mb"   { default = 51200 }
variable "memory_mb"      { default = 4096 }
variable "cpus"           { default = 2 }

source "hyperv-iso" "ubuntu" {
  vm_name           = var.vm_name
  generation        = 2
  cpus              = var.cpus
  memory            = var.memory_mb
  disk_size         = var.disk_size_mb
  switch_name       = var.switch_name
  iso_url           = var.iso_url
  iso_checksum      = var.iso_checksum
  enable_secure_boot = false
  headless          = true
  output_directory  = var.output_dir

  boot_wait    = "5s"
  boot_command = [
    "<enter><wait5>",
    "<enter><wait5>",
    "<f6><esc>",
    "autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ <enter>"
  ]

  http_directory = "packer/hyperv/http/ubuntu"
  ssh_username   = "ubuntu"
  ssh_password   = var.ssh_password
  ssh_timeout    = "30m"

  shutdown_command = "sudo shutdown -P now"
}

build {
  sources = ["source.hyperv-iso.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y python3 python3-pip openssh-server cloud-init",
      "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config",
      "sudo systemctl enable ssh",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo cloud-init clean",
      "sudo truncate -s 0 /etc/machine-id"
    ]
  }

  post-processor "manifest" {
    output     = "${var.output_dir}/manifest.json"
    strip_path = true
  }
}
