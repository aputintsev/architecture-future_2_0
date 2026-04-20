terraform {
  required_version = ">= 1.3.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.84"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.zone_a
}

# ── Data Sources ──────────────────────────────────────────────────────────────

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ── VPC ───────────────────────────────────────────────────────────────────────

resource "yandex_vpc_network" "main" {
  name = "${var.project_name}-vpc"
}

# NAT Gateway provides outbound internet for private subnets without exposing VMs
resource "yandex_vpc_gateway" "nat" {
  name = "${var.project_name}-nat-gw"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private" {
  name       = "${var.project_name}-private-rt"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

# Management subnet — monitoring node, jump host; has direct NAT via instance-level flag
resource "yandex_vpc_subnet" "management" {
  name           = "${var.project_name}-management"
  zone           = var.zone_a
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.management_cidr]
}

# Data platform subnet — Kafka, Nessie; internet via NAT Gateway
resource "yandex_vpc_subnet" "data_platform" {
  name           = "${var.project_name}-data-platform"
  zone           = var.zone_a
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.data_platform_cidr]
  route_table_id = yandex_vpc_route_table.private.id
}

# Analytics subnet — Dremio, Airflow; internet via NAT Gateway
resource "yandex_vpc_subnet" "analytics" {
  name           = "${var.project_name}-analytics"
  zone           = var.zone_b
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.analytics_cidr]
  route_table_id = yandex_vpc_route_table.private.id
}

# AI subnet — AI/ML workloads that need access to medical data
resource "yandex_vpc_subnet" "ai" {
  name           = "${var.project_name}-ai"
  zone           = var.zone_b
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.ai_cidr]
  route_table_id = yandex_vpc_route_table.private.id
}

# Medical subnet — Kafka topics and Nessie catalog for medical data.
# Accessible ONLY from AI subnet. Analytics subnet has no route here (ФЗ-323, 152-ФЗ).
resource "yandex_vpc_subnet" "medical" {
  name           = "${var.project_name}-medical"
  zone           = var.zone_a
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.medical_cidr]
  route_table_id = yandex_vpc_route_table.private.id
}

# ── Security Groups ───────────────────────────────────────────────────────────

resource "yandex_vpc_security_group" "management" {
  name       = "${var.project_name}-sg-management"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.admin_cidr]
    description    = "SSH from admin"
  }

  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = [var.admin_cidr]
    description    = "Grafana UI"
  }

  ingress {
    protocol       = "TCP"
    port           = 9090
    v4_cidr_blocks = [var.management_cidr, var.data_platform_cidr, var.analytics_cidr, var.ai_cidr, var.medical_cidr]
    description    = "Prometheus scrape endpoint"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "data_platform" {
  name       = "${var.project_name}-sg-data-platform"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.management_cidr]
    description    = "SSH from management subnet"
  }

  ingress {
    protocol       = "TCP"
    port           = 9092
    v4_cidr_blocks = [var.data_platform_cidr, var.analytics_cidr, var.ai_cidr]
    description    = "Kafka broker — non-medical domains only (analytics explicitly allowed)"
  }

  ingress {
    protocol       = "TCP"
    port           = 19120
    v4_cidr_blocks = [var.data_platform_cidr, var.analytics_cidr]
    description    = "Nessie REST API — non-medical catalog (Iceberg)"
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

resource "yandex_vpc_security_group" "analytics" {
  name       = "${var.project_name}-sg-analytics"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.management_cidr]
    description    = "SSH from management subnet"
  }

  ingress {
    protocol       = "TCP"
    port           = 9047
    v4_cidr_blocks = [var.analytics_cidr, var.management_cidr]
    description    = "Dremio Web UI"
  }

  ingress {
    protocol       = "TCP"
    port           = 31010
    v4_cidr_blocks = [var.analytics_cidr]
    description    = "Dremio ODBC/JDBC client endpoint"
  }

  ingress {
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = [var.analytics_cidr, var.management_cidr]
    description    = "Apache Airflow WebServer"
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

# Medical security group — enforces the regulatory requirement at network layer:
# only AI subnet may reach medical Kafka and Nessie; analytics subnet is explicitly excluded.
resource "yandex_vpc_security_group" "medical" {
  name       = "${var.project_name}-sg-medical-platform"
  network_id = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.management_cidr]
    description    = "SSH from management subnet only"
  }

  ingress {
    protocol       = "TCP"
    port           = 9092
    v4_cidr_blocks = [var.ai_cidr]
    description    = "Kafka medical topics — AI subnet only (ФЗ-323)"
  }

  ingress {
    protocol       = "TCP"
    port           = 19120
    v4_cidr_blocks = [var.ai_cidr]
    description    = "Nessie medical catalog — AI subnet only (ФЗ-323)"
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

# ── Static Public IP (monitoring node) ───────────────────────────────────────

resource "yandex_vpc_address" "monitoring" {
  name = "${var.project_name}-monitoring-ip"
  external_ipv4_address {
    zone_id = var.zone_a
  }
}

# ── Additional Disks ──────────────────────────────────────────────────────────

resource "yandex_compute_disk" "kafka_data" {
  name = "${var.project_name}-kafka-data"
  type = "network-ssd"
  zone = var.zone_a
  size = var.kafka_disk_size_gb
}

resource "yandex_compute_disk" "dremio_data" {
  name = "${var.project_name}-dremio-data"
  type = "network-ssd"
  zone = var.zone_b
  size = var.dremio_disk_size_gb
}

# ── VMs ───────────────────────────────────────────────────────────────────────

# Monitoring node: Grafana + Prometheus — needs public IP, sits in management subnet
resource "yandex_compute_instance" "monitoring" {
  name        = "${var.project_name}-monitoring"
  platform_id = "standard-v3"
  zone        = var.zone_a

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.management.id
    security_group_ids = [yandex_vpc_security_group.management.id]
    nat                = true
    nat_ip_address     = yandex_vpc_address.monitoring.external_ipv4_address[0].address
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Kafka broker — data platform subnet, private only
resource "yandex_compute_instance" "kafka" {
  name        = "${var.project_name}-kafka"
  platform_id = "standard-v3"
  zone        = var.zone_a

  resources {
    cores         = var.kafka_cores
    memory        = var.kafka_memory_gb
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.kafka_data.id
    device_name = "kafka-data"
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.data_platform.id
    security_group_ids = [yandex_vpc_security_group.data_platform.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Nessie catalog server (Apache Iceberg REST catalog) — data platform subnet
resource "yandex_compute_instance" "nessie" {
  name        = "${var.project_name}-nessie"
  platform_id = "standard-v3"
  zone        = var.zone_a

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.data_platform.id
    security_group_ids = [yandex_vpc_security_group.data_platform.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Dremio query engine — analytics subnet, high CPU/RAM for distributed queries
resource "yandex_compute_instance" "dremio" {
  name        = "${var.project_name}-dremio"
  platform_id = "standard-v3"
  zone        = var.zone_b

  resources {
    cores         = var.dremio_cores
    memory        = var.dremio_memory_gb
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.dremio_data.id
    device_name = "dremio-data"
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.analytics.id
    security_group_ids = [yandex_vpc_security_group.analytics.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Apache Airflow — analytics subnet, orchestrates ETL pipelines and CDC jobs
resource "yandex_compute_instance" "airflow" {
  name        = "${var.project_name}-airflow"
  platform_id = "standard-v3"
  zone        = var.zone_b

  resources {
    cores         = var.airflow_cores
    memory        = var.airflow_memory_gb
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.analytics.id
    security_group_ids = [yandex_vpc_security_group.analytics.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Medical Kafka — dedicated broker for medical topics; isolated in medical subnet.
# SG allows connections only from AI subnet — Dremio/Airflow in analytics subnet cannot reach it.
resource "yandex_compute_disk" "kafka_medical_data" {
  name = "${var.project_name}-kafka-medical-data"
  type = "network-ssd"
  zone = var.zone_a
  size = var.kafka_disk_size_gb
}

resource "yandex_compute_instance" "kafka_medical" {
  name        = "${var.project_name}-kafka-medical"
  platform_id = "standard-v3"
  zone        = var.zone_a

  resources {
    cores         = var.kafka_cores
    memory        = var.kafka_memory_gb
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.kafka_medical_data.id
    device_name = "kafka-medical-data"
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.medical.id
    security_group_ids = [yandex_vpc_security_group.medical.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# Medical Nessie — Iceberg catalog for medical data; AI services use this to locate Parquet files.
resource "yandex_compute_instance" "nessie_medical" {
  name        = "${var.project_name}-nessie-medical"
  platform_id = "standard-v3"
  zone        = var.zone_a

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.medical.id
    security_group_ids = [yandex_vpc_security_group.medical.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

# ── Object Storage — Data Lake ────────────────────────────────────────────────

resource "yandex_storage_bucket" "datalake" {
  bucket     = var.datalake_bucket_name
  access_key = var.s3_access_key
  secret_key = var.s3_secret_key
}

# ── Domain Services ───────────────────────────────────────────────────────────
# Fintech domain is deployed as an example of the domain module pattern.
# Other domains (clinics, partners, medical, ai) follow the same pattern —
# add a module block per domain with the appropriate subnet and parameters.

module "fintech" {
  source = "./modules/domain"

  name            = "fintech"
  project_name    = var.project_name
  zone            = var.zone_a
  subnet_id       = yandex_vpc_subnet.data_platform.id
  network_id      = yandex_vpc_network.main.id
  management_cidr = var.management_cidr
  image_id        = data.yandex_compute_image.ubuntu.id
  ssh_public_key  = var.ssh_public_key

  service_cores     = 2
  service_memory_gb = 4

  create_postgres = true
  db_name         = "fintech"
  db_user         = "fintech"
  db_password     = var.domain_db_passwords["fintech"]
}
