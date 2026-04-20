output "service_internal_ip" {
  description = "Internal IP of the domain service VM"
  value       = yandex_compute_instance.service.network_interface[0].ip_address
}

output "db_host" {
  description = "PostgreSQL cluster host FQDN (empty if create_postgres = false)"
  value       = var.create_postgres ? yandex_mdb_postgresql_cluster.db[0].host[0].fqdn : ""
}

output "security_group_id" {
  description = "Security group ID of the domain service VM"
  value       = yandex_vpc_security_group.domain.id
}
