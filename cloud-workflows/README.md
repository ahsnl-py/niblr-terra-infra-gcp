# Cloud Workflows for Service Management

This Terraform configuration creates Google Cloud Workflows to manage your scrapaz-service and niblr-airflow-service VMs.

## Features

- **Start Services Workflow**: Starts both VM instances
- **Stop Services Workflow**: Stops both VM instances  
- **Check Status Workflow**: Monitors the status of both VMs
- **Update Scrapaz IP Workflow**: Updates the scrapaz service IP in the airflow service metadata
- **Scheduled Execution**: Optional Cloud Scheduler jobs for weekend automation
- **Service Account**: Dedicated service account with minimal required permissions

## Prerequisites

1. Google Cloud Project with Compute Engine API enabled
2. Cloud Workflows API enabled
3. Cloud Scheduler API enabled (if using scheduled jobs)
4. Service account credentials file

## Usage

### Deploy the Workflows

```bash
cd cloud-workflows

# Copy the example variables file and modify as needed
cp terraform.tfvars.example terraform.tfvars

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### Manual Execution

```bash
# Start services
gcloud workflows execute start-services-workflow --location=europe-west3

# Stop services
gcloud workflows execute stop-services-workflow --location=europe-west3

# Check status
gcloud workflows execute check-services-status-workflow --location=europe-west3

# Update scrapaz IP
gcloud workflows execute update-scrapaz-ip-workflow --location=europe-west3
```

### Enable Weekend Scheduling

To enable automatic weekend start/stop scheduling (Saturday 7 AM - Sunday 7 PM), you can either:

1. **Using terraform.tfvars file (recommended):**
   ```bash
   # Edit terraform.tfvars
   enable_scheduled_start = true
   enable_scheduled_stop = true
   
   # Apply changes
   terraform apply
   ```

2. **Using command line variables:**
   ```bash
   terraform apply -var="enable_scheduled_start=true" -var="enable_scheduled_stop=true"
   ```

**Schedule Details:**
- **Start**: Every Saturday at 7:00 AM
- **Stop**: Every Saturday at 10:00 PM
- **Update IP**: Every Saturday at 8:00 AM
- **Time Zone**: Europe/Berlin

## Workflow Details

### Start Services Workflow
- Starts `scrapaz-service-vm` instance
- Starts `niblr-airflow-ubuntu` instance
- Waits 60 seconds for services to initialize
- Returns execution status
- **Scheduled**: Saturday at 7 AM (when enabled)

### Stop Services Workflow
- Stops `scrapaz-service-vm` instance
- Stops `niblr-airflow-ubuntu` instance
- Waits 30 seconds for graceful shutdown
- Returns execution status
- **Scheduled**: Saturday at 10 PM (when enabled)

### Check Status Workflow
- Retrieves current status of both VM instances
- Returns detailed status information including:
  - Instance names
  - Current status (RUNNING, STOPPED, etc.)
  - Zone information

### Update Scrapaz IP Workflow
- Retrieves the current IP address of `scrapaz-service-vm`
- Updates the `SCRAPAZ_SERVICE_IP` metadata item on `niblr-airflow-ubuntu`
- Ensures the airflow service always has the correct scrapaz service IP
- Returns the updated IP address and execution status
- **Scheduled**: Saturday at 8 AM (when enabled)

## Security

The workflows use a dedicated service account with minimal permissions:
- `roles/compute.instanceAdmin.v1` - To start/stop instances
- `roles/compute.viewer` - To check instance status

## Monitoring

You can monitor workflow executions in the Google Cloud Console:
1. Go to Cloud Workflows
2. Select your workflow
3. View execution history and logs

## Cost Optimization

- Use weekend scheduling to automatically start services only when needed (Saturday 7 AM - Saturday 10 PM)
- Services will be stopped during weekdays to save costs
- IP updates are scheduled to ensure services can communicate properly
- Monitor workflow execution costs in Cloud Console
- Consider using Cloud Functions for simpler use cases if cost is a concern

## Troubleshooting

### Common Issues

1. **Workflow execution fails with authentication error:**
   - Ensure the service account has the correct IAM roles
   - Verify the credentials file path is correct
   - Check that the Compute Engine API is enabled

2. **VM instance not found:**
   - Verify the VM instance names match exactly: `scrapaz-service-vm` and `niblr-airflow-ubuntu`
   - Ensure the VMs exist in the specified zone
   - Check that the project ID is correct

3. **Scheduled jobs not running:**
   - Verify Cloud Scheduler API is enabled
   - Check the service account has `workflows.invoker` role
   - Review Cloud Scheduler logs in the console

### Enable Required APIs

Make sure these APIs are enabled in your Google Cloud project:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable workflows.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
``` 