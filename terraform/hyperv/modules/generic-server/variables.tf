variable "server_name"           { type = string }
variable "attack_range_id"       { type = string }
variable "attack_range_password" { type = string ; sensitive = true }
variable "vhdx_path"             { type = string }
variable "cpus"                  { type = number ; default = 2 }
variable "memory_mb"             { type = number ; default = 4096 }
variable "disk_size_gb"          { type = number ; default = 60 }
variable "switch_name"           { type = string }
variable "private_ip"            { type = string }
variable "gateway_ip"            { type = string }
variable "windows"               { type = bool   ; default = false }
variable "user_name"             { type = string ; default = "ubuntu" }
variable "ssh_public_key"        { type = string ; default = "" }
variable "password"              { type = string ; sensitive = true }
variable "vm_base_path"          { type = string ; default = "C:/AttackRangeVMs" }
