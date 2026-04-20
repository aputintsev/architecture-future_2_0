# ── Yandex Cloud credentials ──────────────────────────────────────────────────
# yc_token, ssh_public_key, s3_access_key, s3_secret_key are sensitive.
# Pass them via environment variables to avoid storing secrets in version control:
#
#   export TF_VAR_yc_token="$(yc iam create-token)"
#   export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
#   export TF_VAR_s3_access_key="<static-key-id>"
#   export TF_VAR_s3_secret_key="<static-key-secret>"

yc_cloud_id  = "b1gronnig4r9k8oac4e2"   # yc resource-manager cloud list
yc_folder_id = "b1g7kh2jmt4dclur6ve2"  # yc resource-manager folder list

# ── Project ───────────────────────────────────────────────────────────────────

project_name = "future20"

# ── Availability zones ────────────────────────────────────────────────────────

zone_a = "ru-central1-a"
zone_b = "ru-central1-b"

# ── Network ───────────────────────────────────────────────────────────────────

management_cidr    = "10.0.0.0/24"
data_platform_cidr = "10.0.1.0/24"
analytics_cidr     = "10.0.2.0/24"
ai_cidr            = "10.0.3.0/24"
medical_cidr       = "10.0.4.0/24"

# Replace with the actual IP range of your administrators
admin_cidr = "0.0.0.0/0"

# ── Kafka (4 vCPU / 16 GB / 500 GB SSD) ──────────────────────────────────────

kafka_cores        = 4
kafka_memory_gb    = 16
kafka_disk_size_gb = 20   # prod: 500 GB; reduced for demo/test quota limits

# ── Dremio (8 vCPU / 32 GB / 200 GB SSD) ─────────────────────────────────────

dremio_cores        = 8
dremio_memory_gb    = 32
dremio_disk_size_gb = 20  # prod: 200 GB; reduced for demo/test quota limits

# ── Airflow (4 vCPU / 8 GB) ───────────────────────────────────────────────────

airflow_cores     = 4
airflow_memory_gb = 8

# ── Object Storage ────────────────────────────────────────────────────────────

datalake_bucket_name = "future20-datalake"

# ── Domain DB passwords ───────────────────────────────────────────────────────
# Set via environment variable — do NOT commit real passwords:
#   export TF_VAR_domain_db_passwords='{"fintech":"..."}'
