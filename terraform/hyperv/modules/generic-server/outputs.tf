output "private_ip" {
  value = var.private_ip
}

output "vm_name" {
  value = hyperv_machine_instance.server.name
}
