terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140.0"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

module "vm_module" {
  source = "../Task1Advanced/modules/vm"

  name           = var.name
  zone           = var.zone
  cores          = var.cores
  memory         = var.memory
  disk_size      = var.disk_size
  subnet_id      = var.subnet_id
  ssh_public_key = var.ssh_public_key
  ssh_user       = var.ssh_user
  image_family   = var.image_family
  platform_id    = var.platform_id
  boot_disk_size = var.boot_disk_size
  disk_type      = var.disk_type
  nat            = var.nat
}
