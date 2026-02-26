terraform {
  required_version = ">= 1.5.0"
}

locals {
  zeek_server_enabled = length([
    for s in var.attack_range : s if try(s.zeek, false) || s.name == "zeek"
  ]) > 0

  zeek_server_config = try(
    [for s in var.attack_range : s if try(s.zeek, false) || s.name == "zeek"][0],
    null
  )

  non_zeek_servers = {
    for s in var.attack_range : s.name => s
    if !try(s.zeek, false) && s.name != "zeek"
  }
}

module "network" {
  source           = "./modules/network"
  switch_wan       = var.hyperv.switch_wan
  switch_mgmt      = var.hyperv.switch_mgmt
  switch_ips1      = var.hyperv.switch_ips1
  switch_ips2      = var.hyperv.switch_ips2
  nat_name         = var.hyperv.nat_name
  host_wan_ip      = var.hyperv.host_wan_ip
  host_mgmt_ip     = var.hyperv.host_mgmt_ip
  attack_range_id  = var.general.attack_range_id
}

module "router" {
  source           = "./modules/router"
  switch_wan       = var.hyperv.switch_wan
  switch_mgmt      = var.hyperv.switch_mgmt
  switch_ips1      = var.hyperv.switch_ips1
  host_mgmt_ip     = var.hyperv.host_mgmt_ip
  subnet_mgmt      = var.hyperv.subnet_mgmt
  subnet_targets   = var.hyperv.subnet_targets
  password         = var.general.attack_range_password
  attack_range_id  = var.general.attack_range_id
  depends_on       = [module.network]
}

module "zeek_server" {
  source          = "./modules/zeek-server"
  enabled         = local.zeek_server_enabled
  config          = local.zeek_server_config
  switch_mgmt     = var.hyperv.switch_mgmt
  switch_ips1     = var.hyperv.switch_ips1
  switch_ips2     = var.hyperv.switch_ips2
  splunk_ip       = "172.16.100.10"
  password        = var.general.attack_range_password
  attack_range_id = var.general.attack_range_id
  depends_on      = [module.router]
}

module "attack_range_servers" {
  source          = "./modules/generic-server"
  for_each        = local.non_zeek_servers
  server          = each.value
  switch_mgmt     = var.hyperv.switch_mgmt
  switch_ips1     = var.hyperv.switch_ips1
  switch_ips2     = var.hyperv.switch_ips2
  password        = var.general.attack_range_password
  attack_range_id = var.general.attack_range_id
  depends_on      = [module.router]
}
