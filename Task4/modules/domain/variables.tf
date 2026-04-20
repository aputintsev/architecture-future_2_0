variable "name" {
  type        = string
  description = "Domain name — used as resource name suffix (e.g. fintech, clinics)"
}

variable "project_name" {
  type        = string
  description = "Global project prefix inherited from root module"
}

variable "zone" {
  type        = string
  description = "Availability zone for VM and PostgreSQL host"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the domain service VM and DB will be placed"
}

variable "network_id" {
  type        = string
  description = "VPC network ID (for security group creation)"
}

variable "management_cidr" {
  type        = string
  description = "CIDR of management subnet — allowed for SSH"
}

variable "allowed_app_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the domain service on application ports (defaults to whole VPC)"
  default     = ["10.0.0.0/16"]
}

variable "image_id" {
  type        = string
  description = "Boot disk image ID (Ubuntu 22.04 LTS from root data source)"
}

variable "ssh_public_key" {
  type        = string
  sensitive   = true
  description = "SSH public key for VM access"
}

variable "service_cores" {
  type        = number
  description = "vCPUs for domain service VM"
  default     = 2
}

variable "service_memory_gb" {
  type        = number
  description = "RAM in GB for domain service VM"
  default     = 4
}

# ── PostgreSQL ─────────────────────────────────────────────────────────────────

variable "create_postgres" {
  type        = bool
  description = "Whether to create a managed PostgreSQL cluster for this domain"
  default     = true
}

variable "db_name" {
  type        = string
  description = "PostgreSQL database name"
}

variable "db_user" {
  type        = string
  description = "PostgreSQL user name"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "PostgreSQL user password"
  default     = ""
}
