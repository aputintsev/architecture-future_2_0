output "monitoring_public_ip" {
  description = "Public IP of the monitoring node (Grafana :3000, Prometheus :9090)"
  value       = yandex_vpc_address.monitoring.external_ipv4_address[0].address
}

output "kafka_internal_ip" {
  description = "Internal IP of the Kafka broker (port 9092)"
  value       = yandex_compute_instance.kafka.network_interface[0].ip_address
}

output "nessie_internal_ip" {
  description = "Internal IP of the Nessie catalog server (port 19120)"
  value       = yandex_compute_instance.nessie.network_interface[0].ip_address
}

output "dremio_internal_ip" {
  description = "Internal IP of Dremio coordinator (Web UI :9047, JDBC :31010)"
  value       = yandex_compute_instance.dremio.network_interface[0].ip_address
}

output "airflow_internal_ip" {
  description = "Internal IP of the Airflow WebServer (port 8080)"
  value       = yandex_compute_instance.airflow.network_interface[0].ip_address
}

output "nessie_medical_internal_ip" {
  description = "Internal IP of the medical Nessie catalog (accessible from AI subnet only)"
  value       = yandex_compute_instance.nessie_medical.network_interface[0].ip_address
}

output "datalake_bucket_name" {
  description = "Name of the object storage bucket used as the Data Lake"
  value       = yandex_storage_bucket.datalake.bucket
}

output "fintech_service_ip" {
  description = "Internal IP of the fintech domain service VM"
  value       = module.fintech.service_internal_ip
}

output "fintech_db_host" {
  description = "PostgreSQL FQDN for the fintech domain"
  value       = module.fintech.db_host
}

output "vpc_id" {
  description = "ID of the main VPC"
  value       = yandex_vpc_network.main.id
}

output "nat_gateway_id" {
  description = "ID of the shared NAT gateway"
  value       = yandex_vpc_gateway.nat.id
}
