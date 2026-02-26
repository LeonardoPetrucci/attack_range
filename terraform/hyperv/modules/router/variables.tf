variable "attack_range_id" { type = string }
variable "vhdx_path"       { type = string }
variable "external_switch" { type = string }
variable "internal_switch" { type = string }
variable "private_ip"      { type = string }
variable "router_ip"       { type = string }
variable "ssh_public_key"  { type = string }
variable "password"        { type = string ; sensitive = true }
variable "user_name"       { type = string  ; default = "ubuntu" }
variable "internal_subnet" { type = string  ; default = "10.0.2.0/24" }
variable "vm_base_path"    { type = string  ; default = "C:/AttackRangeVMs" }
variable "cpus"            { type = number  ; default = 2 }
variable "memory_mb"       { type = number  ; default = 2048 }
