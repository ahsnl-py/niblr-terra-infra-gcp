# Terraform Docker Airflow GCP

Terraform infrastructure to deploy Docker-based services on Google Cloud Platform with automated Cloud Workflows for service management.

## Overview

This project deploys:
- **Scrapaz Service**: Web scraping service running on port 8001
- **Niblr Airflow Service**: Apache Airflow for workflow orchestration
- **Cloud Workflows**: Automated start/stop scheduling (Saturday 7 AM - Sunday 12 AM)

## Prerequisites

- Google Cloud Platform account
- Google Cloud CLI installed and configured
- Terraform installed
- SSH key pair for VM access

## Quick Start

### 1. Setup Google Cloud

1. Create a GCP project
2. Enable required APIs:
   ```bash
   gcloud services enable compute.googleapis.com
   gcloud services enable workflows.googleapis.com
   gcloud services enable cloudscheduler.googleapis.com
   ```

### 2. Create Service Account

1. Create a service account with these roles:
   - Compute Engine Admin
   - Workflows Admin
   - Cloud Scheduler Admin
   - Service Account User

2. Download the JSON key and save it as `.google/credentials/sa-cloud-workflow.json`

### 3. Generate SSH Key

```bash
ssh-keygen -t rsa -f ~/.ssh/gcp_key -C your-email@example.com
```

### 4. Deploy Infrastructure

```bash
# Deploy scrapaz service
cd scrapaz-service
terraform init
terraform apply

# Deploy niblr-airflow service
cd ../niblr-airflow-service
terraform init
terraform apply

# Deploy Cloud Workflows
cd ../cloud-workflows
terraform init
terraform apply
```

## Configuration

### Variables

Update these variables in each service's `variables.tf`:

- `project`: Your GCP project ID
- `region`: GCP region (default: europe-west3)
- `zone`: GCP zone (default: europe-west3-a)
- `user`: VM username
- `ssh_key_file`: Path to your SSH public key

### Cloud Workflows Schedule

- **Start Services**: Saturday 7:00 AM
- **Stop Services**: Saturday 11:59 PM (Sunday 12:00 AM)

To enable scheduling:
```bash
cd cloud-workflows
terraform apply -var="enable_scheduled_start=true" -var="enable_scheduled_stop=true"
```

## Manual Workflow Execution

```bash
# Start services
gcloud workflows execute start-services-workflow --location=europe-west3

# Stop services
gcloud workflows execute stop-services-workflow --location=europe-west3

# Check service status
gcloud workflows execute check-services-status-workflow --location=europe-west3
```

## Access Services

After deployment, you'll get the public IP addresses in the Terraform output:

- **Scrapaz Service**: `http://<IP>:8001`
- **Niblr Airflow**: `http://<IP>:8080`

## Project Structure

```
├── scrapaz-service/          # Web scraping service
├── niblr-airflow-service/    # Apache Airflow service
├── cloud-workflows/          # Automated service management
├── .google/                  # Service account credentials
└── README.md
```

## Cleanup

To destroy all resources:
```bash
cd scrapaz-service && terraform destroy
cd ../niblr-airflow-service && terraform destroy
cd ../cloud-workflows && terraform destroy
```

## Support

For issues or questions, please check the individual service directories for specific documentation.
