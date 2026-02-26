###############################################################################
# Attack Range - Hyper-V Provider
# Replaces terraform/aws/main.tf
# Uses the community bmatcuk/hyperv Terraform provider.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    hyperv = {
      source  = "bmatcuk/hyperv"
      version = "~> 1.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }

  # backend.tf is generated dynamically by HyperVProvider.write_backend_config()
  # at build time, pointing to a local .tfstate file under config/
}

provider "hyperv" {
  user     = var.hyperv_host.username
  password = var.hyperv_host.password
  host     = var.hyperv_host.host
  port     = var.hyperv_host.port
  https    = var.hyperv_host.https
  insecure = var.hyperv_host.insecure
  use_ntlm = var.hyperv_host.use_ntlm
  timeout  = "120s"
}

###############################################################################
# Network: internal Hyper-V switch + Windows NAT
###############################################################################
module "networkModule" {
  source          = "./modules/network"
  attack_range_id = var.general.attack_range_id
  nat_subnet      = var.network.nat_subnet
  nat_gateway_ip  = var.network.nat_gateway_ip
}

###############################################################################
# Router: Ubuntu VM acting as WireGuard VPN server
###############################################################################
module "router" {
  source          = "./modules/router"
  attack_range_id = var.general.attack_range_id
  vhdx_path       = var.router.vhdx_path
  cpus            = var.router.cpus
  memory_mb       = var.router.memory_mb
  ssh_public_key  = var.general.ssh_public_key
  password        = var.general.attack_range_password
  internal_switch = module.networkModule.switch_name
  external_switch = var.router.external_switch
  private_ip      = var.network.nat_gateway_ip
  router_ip       = var.router.router_ip
  vm_base_path    = var.hyperv_host.vm_base_path
}

###############################################################################
# Lab servers: one VM per entry in var.attack_range
###############################################################################
module "attack_range_servers" {
  source   = "./modules/generic-server"
  for_each = { for server in var.attack_range : server.name => server }

  server_name           = each.value.name
  attack_range_id       = var.general.attack_range_id
  attack_range_password = var.general.attack_range_password
  vhdx_path             = each.value.vhdx_path
  cpus                  = try(each.value.cpus, 2)
  memory_mb             = try(each.value.memory_mb, 4096)
  disk_size_gb          = try(each.value.disk_size_gb, 60)
  switch_name           = module.networkModule.switch_name
  private_ip            = "${var.network.ip_prefix}.${each.value.ip_last_octet}"
  gateway_ip            = var.network.nat_gateway_ip
  windows               = try(each.value.windows, false)
  user_name             = try(each.value.user_name, "ubuntu")
  ssh_public_key        = var.general.ssh_public_key
  password              = var.general.attack_range_password
  vm_base_path          = var.hyperv_host.vm_base_path
}
