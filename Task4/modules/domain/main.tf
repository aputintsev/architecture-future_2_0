terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# Security group for this domain's service VM
resource "yandex_vpc_security_group" "domain" {
  name       = "${var.project_name}-sg-${var.name}"
  network_id = var.network_id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.management_cidr]
    description    = "SSH from management subnet"
  }

  ingress {
    protocol       = "TCP"
    from_port      = 8000
    to_port        = 9000
    v4_cidr_blocks = var.allowed_app_cidrs
    description    = "Application ports (REST API, gRPC)"
  }

  ingress {
    protocol       = "TCP"
    port           = 9100
    v4_cidr_blocks = [var.management_cidr]
    description    = "Prometheus node exporter"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Domain service VM — runs the business logic microservice (Java, Go, Python)
resource "yandex_compute_instance" "service" {
  name        = "${var.project_name}-${var.name}-svc"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = var.service_cores
    memory        = var.service_memory_gb
    core_fraction = 20  # burstable: saves cost for services without constant load
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    security_group_ids = [yandex_vpc_security_group.domain.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Managed PostgreSQL — each domain owns its own database cluster (Data Mesh principle)
resource "yandex_mdb_postgresql_cluster" "db" {
  count       = var.create_postgres ? 1 : 0
  name        = "${var.project_name}-pg-${var.name}"
  environment = "PRESTABLE"
  network_id  = var.network_id

  config {
    version = "15"
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 10
    }
  }

  host {
    zone      = var.zone
    subnet_id = var.subnet_id
  }
}

resource "yandex_mdb_postgresql_user" "db_user" {
  count      = var.create_postgres ? 1 : 0
  cluster_id = yandex_mdb_postgresql_cluster.db[0].id
  name       = var.db_user
  password   = var.db_password
}

resource "yandex_mdb_postgresql_database" "db" {
  count      = var.create_postgres ? 1 : 0
  cluster_id = yandex_mdb_postgresql_cluster.db[0].id
  name       = var.db_name
  owner      = yandex_mdb_postgresql_user.db_user[0].name

  depends_on = [yandex_mdb_postgresql_user.db_user]
}
