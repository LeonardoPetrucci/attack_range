output "router_public_ip" {
  description = "Hyper-V host IP used as WireGuard endpoint"
  value       = module.router.router_ip
}

output "server_ips" {
  description = "Map of server name to private IP"
  value       = { for k, v in module.attack_range_servers : k => v.private_ip }
}
