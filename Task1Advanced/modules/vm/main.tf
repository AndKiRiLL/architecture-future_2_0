terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.140.0"
    }
  }
}

data "yandex_compute_image" "os" {
  family = var.image_family
}

resource "yandex_compute_disk" "data" {
  name = "${var.name}-data"
  zone = var.zone
  type = var.disk_type
  size = var.disk_size
}

resource "yandex_compute_instance" "vm" {
  name        = var.name
  zone        = var.zone
  platform_id = var.platform_id

  resources {
    cores  = var.cores
    memory = var.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.id
      size     = var.boot_disk_size
      type     = var.disk_type
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.data.id
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = var.nat
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${trimspace(var.ssh_public_key)}"
  }
}
