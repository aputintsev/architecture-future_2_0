variable "yc_token" {
  type        = string
  description = "Yandex Cloud IAM token (export YC_TOKEN=... or set here)"
  sensitive   = true
}

variable "yc_cloud_id" {
  type        = string
  description = "Yandex Cloud ID"
}

variable "yc_folder_id" {
  type        = string
  description = "Yandex Cloud Folder ID"
}

variable "project_name" {
  type        = string
  description = "Prefix for all resource names"
  default     = "future20"
}

# ── Zones ────────────────────────────────────────────────────────────────────

variable "zone_a" {
  type    = string
  default = "ru-central1-a"
}

variable "zone_b" {
  type    = string
  default = "ru-central1-b"
}

# ── Network CIDRs ─────────────────────────────────────────────────────────────

variable "management_cidr" {
  type        = string
  description = "CIDR for management subnet (monitoring node)"
  default     = "10.0.0.0/24"
}

variable "data_platform_cidr" {
  type        = string
  description = "CIDR for data platform subnet (Kafka, Nessie)"
  default     = "10.0.1.0/24"
}

variable "analytics_cidr" {
  type        = string
  description = "CIDR for analytics subnet (Dremio, Airflow)"
  default     = "10.0.2.0/24"
}

variable "ai_cidr" {
  type        = string
  description = "CIDR for AI services subnet"
  default     = "10.0.3.0/24"
}

variable "medical_cidr" {
  type        = string
  description = "CIDR for medical data subnet — accessible only from AI subnet (regulatory requirement: ФЗ-323, 152-ФЗ)"
  default     = "10.0.4.0/24"
}

variable "admin_cidr" {
  type        = string
  description = "CIDR of administrator workstations allowed SSH and UI access"
  default     = "0.0.0.0/0"
}

# ── SSH ───────────────────────────────────────────────────────────────────────

variable "ssh_public_key" {
  type        = string
  description = "SSH public key content for VM access"
  sensitive   = true
}

# ── Kafka ─────────────────────────────────────────────────────────────────────

variable "kafka_cores" {
  type        = number
  description = "Number of vCPUs for Kafka broker VM"
  default     = 4
}

variable "kafka_memory_gb" {
  type        = number
  description = "RAM in GB for Kafka broker VM"
  default     = 16
}

variable "kafka_disk_size_gb" {
  type        = number
  description = "Size of Kafka data disk in GB"
  default     = 500
}

# ── Dremio ────────────────────────────────────────────────────────────────────

variable "dremio_cores" {
  type        = number
  description = "Number of vCPUs for Dremio VM (query engine needs more CPU)"
  default     = 8
}

variable "dremio_memory_gb" {
  type        = number
  description = "RAM in GB for Dremio VM (query engine needs more RAM)"
  default     = 32
}

variable "dremio_disk_size_gb" {
  type        = number
  description = "Size of Dremio local cache disk in GB"
  default     = 200
}

# ── Airflow ───────────────────────────────────────────────────────────────────

variable "airflow_cores" {
  type        = number
  description = "Number of vCPUs for Apache Airflow VM"
  default     = 4
}

variable "airflow_memory_gb" {
  type        = number
  description = "RAM in GB for Apache Airflow VM"
  default     = 8
}

# ── Object Storage (Data Lake) ────────────────────────────────────────────────

variable "datalake_bucket_name" {
  type        = string
  description = "Globally unique name for the data lake bucket"
}

# ── Domain DB passwords ───────────────────────────────────────────────────────

variable "domain_db_passwords" {
  type        = map(string)
  sensitive   = true
  description = "PostgreSQL passwords per domain. Set via env var to avoid storing in VCS: export TF_VAR_domain_db_passwords='{\"fintech\":\"...\"}'"
}

variable "s3_access_key" {
  type        = string
  description = "Yandex Object Storage static access key ID"
  sensitive   = true
}

variable "s3_secret_key" {
  type        = string
  description = "Yandex Object Storage static secret key"
  sensitive   = true
}
