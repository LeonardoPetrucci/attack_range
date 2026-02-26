output "router_ip" {
  description = "Hyper-V host IP (WireGuard endpoint)"
  value       = var.router_ip
}

output "vm_name" {
  value = hyperv_machine_instance.router.name
}
