output "server_ips" {
  value = {
    for name, mod in module.attack_range_servers : name => mod.ip
  }
}

output "router_ip" {
  value = module.router.ip
}

output "zeek_ip" {
  value = local.zeek_server_enabled ? module.zeek_server.ip : null
}
