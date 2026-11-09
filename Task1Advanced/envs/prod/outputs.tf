output "vm_id" {
  description = "ID виртуальной машины."
  value       = module.vm_module.vm_id
}

output "vm_name" {
  description = "Имя виртуальной машины."
  value       = module.vm_module.vm_name
}

output "internal_ip" {
  description = "Внутренний IP-адрес."
  value       = module.vm_module.internal_ip
}

output "external_ip" {
  description = "Публичный IP-адрес; пустой при nat = false."
  value       = module.vm_module.external_ip
}

output "disk_id" {
  description = "ID подключённого дополнительного диска."
  value       = module.vm_module.disk_id
}
