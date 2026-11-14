output "vm_id" {
  description = "ID виртуальной машины."
  value       = yandex_compute_instance.vm.id
}

output "vm_name" {
  description = "Имя виртуальной машины."
  value       = yandex_compute_instance.vm.name
}

output "internal_ip" {
  description = "Внутренний IP-адрес."
  value       = yandex_compute_instance.vm.network_interface[0].ip_address
}

output "external_ip" {
  description = "Публичный IP-адрес; пустой при nat = false."
  value       = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}

output "disk_id" {
  description = "ID подключённого дополнительного диска."
  value       = yandex_compute_disk.data.id
}
