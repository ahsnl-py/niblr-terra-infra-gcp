# Scrapaz Service Deployment

This Terraform configuration deploys the [scrapaz-web-crawler](https://github.com/ahsnl-py/scrapaz-web-crawler) service as a FastAPI application on Google Cloud Platform.

## Overview

The deployment creates:
- A VPC network with firewall rules
- A VM instance running the scrapaz service
- A load balancer for production traffic
- Health checks and monitoring

## Prerequisites

1. **Google Cloud SDK** installed and authenticated
2. **Terraform** installed
3. **SSH key pair** generated
4. **GROQ API key** for the web crawler service
5. **Service account** with necessary permissions

## Quick Start

### 1. Setup Variables

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit the file with your values
nano terraform.tfvars
```

**Required variables:**
- `groq_api_key`: Your GROQ API key for the web crawler
- `credentials`: Path to your service account JSON file
- `ssh_key_file`: Path to your SSH public key

### 2. Deploy

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 3. Access the Service

After deployment, you'll get outputs with:
- Direct VM access URL
- Load balancer URL
- SSH connection details

## Service Features

- **FastAPI endpoints** for web crawling requests
- **Docker containerization** for easy deployment
- **Nginx reverse proxy** for production traffic
- **Health checks** for monitoring
- **Automatic restart** on failure
- **Data persistence** with volume mounts

## API Endpoints

The service exposes FastAPI endpoints for:
- Web crawling requests
- Health checks
- API documentation (Swagger UI)

## Monitoring

- **Health check**: `GET /health`
- **Service logs**: `docker logs scrapaz-service`
- **Service status**: `docker ps`

## Troubleshooting

### SSH Access
```bash
ssh -i ~/.ssh/gcp_key ahsnl_mi@<VM_IP>
```

### Check Service Status
```bash
# On the VM
docker ps
docker logs scrapaz-service
```

### Restart Service
```bash
# On the VM
docker restart scrapaz-service
```

### View Nginx Logs
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Cleanup

To destroy the infrastructure:
```bash
terraform destroy
```

## Security Notes

- The service runs on a private VPC with controlled access
- Firewall rules allow only necessary ports (80, 443, 8000)
- Service account credentials are securely stored
- API keys are stored as environment variables

## Cost Optimization

- Uses `e2-medium` machine type (cost-effective)
- 30GB boot disk (sufficient for Docker and dependencies)
- Consider using preemptible instances for development
- Monitor usage with Google Cloud Console 