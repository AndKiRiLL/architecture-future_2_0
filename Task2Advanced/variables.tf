variable "cloud_id" {
  description = "ID облака Yandex Cloud."
  type        = string
}

variable "folder_id" {
  description = "ID каталога Yandex Cloud."
  type        = string
}

variable "name" {
  description = "Имя виртуальной машины."
  type        = string
}

variable "zone" {
  description = "Зона доступности ВМ и диска; должна совпадать с зоной подсети."
  type        = string
}

variable "cores" {
  description = "Количество ядер CPU."
  type        = number
}

variable "memory" {
  description = "Объём оперативной памяти в ГБ."
  type        = number
}

variable "disk_size" {
  description = "Размер дополнительного диска в ГБ."
  type        = number
}

variable "subnet_id" {
  description = "ID существующей подсети Yandex VPC."
  type        = string
}

variable "ssh_user" {
  description = "Пользователь для SSH-подключения."
  type        = string
  default     = "ubuntu"
}

variable "image_family" {
  description = "Семейство публичного образа ОС."
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "platform_id" {
  description = "Аппаратная платформа ВМ."
  type        = string
  default     = "standard-v3"
}

variable "boot_disk_size" {
  description = "Размер загрузочного диска в ГБ."
  type        = number
  default     = 20
}

variable "disk_type" {
  description = "Тип загрузочного и дополнительного дисков."
  type        = string
  default     = "network-hdd"
}

variable "nat" {
  description = "Назначить ВМ публичный IP-адрес."
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Содержимое публичного SSH-ключа. В CI передаётся через TF_VAR_ssh_public_key."
  type        = string
}
