terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials)
  project     = var.project
  region      = var.region
}

# Use the service account from the credentials file
locals {
  workflow_service_account_email = "cloud-workflow-sa@niblr-agentic-service.iam.gserviceaccount.com"
}

# Cloud Workflow for starting services
resource "google_workflows_workflow" "start_services" {
  name            = "start-services-workflow"
  region          = var.region
  description     = "Workflow to start scrapaz-service and niblr-airflow-service VMs"
  service_account = local.workflow_service_account_email

  source_contents = <<-EOF
  # Start Services Workflow
  # This workflow starts both scrapaz-service and niblr-airflow-service VMs
  
  main:
    params: [args]
    steps:
      - start_scrapaz:
          call: http.post
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/scrapaz-service-vm/start
            auth:
              type: OAuth2
            headers:
              Content-Type: application/json
          result: scrapaz_result
      
      - start_niblr_airflow:
          call: http.post
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/niblr-airflow-ubuntu/start
            auth:
              type: OAuth2
            headers:
              Content-Type: application/json
          result: niblr_result
      
      - wait_for_services:
          call: sys.sleep
          args:
            seconds: 60
      
      - return_result:
          return:
            scrapaz_status: scrapaz_result
            niblr_status: niblr_result
            message: "Both services started successfully"
  EOF
}

# Cloud Workflow for stopping services
resource "google_workflows_workflow" "stop_services" {
  name            = "stop-services-workflow"
  region          = var.region
  description     = "Workflow to stop scrapaz-service and niblr-airflow-service VMs"
  service_account = local.workflow_service_account_email

  source_contents = <<-EOF
  # Stop Services Workflow
  # This workflow stops both scrapaz-service and niblr-airflow-service VMs
  
  main:
    params: [args]
    steps:
      - stop_scrapaz:
          call: http.post
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/scrapaz-service-vm/stop
            auth:
              type: OAuth2
            headers:
              Content-Type: application/json
          result: scrapaz_result
      
      - stop_niblr_airflow:
          call: http.post
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/niblr-airflow-ubuntu/stop
            auth:
              type: OAuth2
            headers:
              Content-Type: application/json
          result: niblr_result
      
      - wait_for_stop:
          call: sys.sleep
          args:
            seconds: 30
      
      - return_result:
          return:
            scrapaz_status: scrapaz_result
            niblr_status: niblr_result
            message: "Both services stopped successfully"
  EOF
}

# Cloud Workflow for checking service status
resource "google_workflows_workflow" "check_services_status" {
  name            = "check-services-status-workflow"
  region          = var.region
  description     = "Workflow to check the status of both services"
  service_account = local.workflow_service_account_email

  source_contents = <<-EOF
  # Check Services Status Workflow
  # This workflow checks the status of both VMs
  
  main:
    params: [args]
    steps:
      - get_scrapaz_status:
          call: http.get
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/scrapaz-service-vm
            auth:
              type: OAuth2
          result: scrapaz_status
      
      - get_niblr_status:
          call: http.get
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/niblr-airflow-ubuntu
            auth:
              type: OAuth2
          result: niblr_status
      
      - return_status:
          return:
            scrapaz_service:
              name: scrapaz_status.body.name
              status: scrapaz_status.body.status
              zone: scrapaz_status.body.zone
            niblr_airflow_service:
              name: niblr_status.body.name
              status: niblr_status.body.status
              zone: niblr_status.body.zone
  EOF
}

resource "google_workflows_workflow" "update_scrapaz_ip" {
  name            = "update-scrapaz-ip-workflow"
  region          = var.region
  description     = "Workflow to get scrapaz-service IP and update niblr-airflow environment"
  service_account = local.workflow_service_account_email

  source_contents = <<-EOF
  # Update Scrapaz IP Workflow
  # This workflow gets the current IP of scrapaz-service and updates niblr-airflow environment
  
  main:
    params: [args]
    steps:
      - get_scrapaz_details:
          call: http.get
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/scrapaz-service-vm
            auth:
              type: OAuth2
          result: scrapaz_details
      
      - get_niblr_details:
          try:
            call: http.get
            args:
              url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/niblr-airflow-ubuntu
              auth:
                type: OAuth2
            result: niblr_details
          except:
            as: e
            steps:
              - log_error:
                  assign:
                    - error: e
              - return_error:
                  return: "Instance niblr-airflow-ubuntu not found. Check project/zone."
      
      - extract_data:
          assign:
            - scrapaz_ip: $${scrapaz_details.body.networkInterfaces[0].accessConfigs[0].natIP}
            - fingerprint: $${niblr_details.body.metadata.fingerprint}
      
      - update_airflow_metadata:
          call: http.post
          args:
            url: https://compute.googleapis.com/compute/v1/projects/${var.project}/zones/${var.zone}/instances/niblr-airflow-ubuntu/setMetadata
            auth:
              type: OAuth2
            headers:
              Content-Type: application/json
            body:
              fingerprint: $${fingerprint}
              items:
                - key: "SCRAPAZ_SERVICE_IP"
                  value: $${scrapaz_ip}
      
      - return_result:
          return:
            scrapaz_ip: $${scrapaz_ip}
            niblr_status: $${niblr_details.body.status}
            message: "Successfully updated SCRAPAZ_SERVICE_IP environment variable"
  EOF
}

# Cloud Scheduler job to start services (Saturday at 7 AM)
resource "google_cloud_scheduler_job" "start_services_schedule" {
  count     = var.enable_scheduled_start ? 1 : 0
  name      = "start-services-weekend"
  description = "Start services on Saturday at 7 AM"
  schedule  = var.start_schedule
  time_zone = "Europe/Berlin"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project}/locations/${var.region}/workflows/${google_workflows_workflow.start_services.name}/executions"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = local.workflow_service_account_email
    }
  }
}

# Cloud Scheduler job to stop services (Saturday at 10 PM)
resource "google_cloud_scheduler_job" "stop_services_schedule" {
  count     = var.enable_scheduled_stop ? 1 : 0
  name      = "stop-services-weekend"
  description = "Stop services on Saturday at 10 PM"
  schedule  = var.stop_schedule
  time_zone = "Europe/Berlin"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project}/locations/${var.region}/workflows/${google_workflows_workflow.stop_services.name}/executions"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = local.workflow_service_account_email
    }
  }
}

# Cloud Scheduler job to update scrapaz IP (Saturday at 8 AM)
resource "google_cloud_scheduler_job" "update_scrapaz_ip_schedule" {
  count     = var.enable_scheduled_start ? 1 : 0
  name      = "update-scrapaz-ip-weekend"
  description = "Update scrapaz service IP on Saturday at 8 AM"
  schedule  = "0 8 * * 6"
  time_zone = "Europe/Berlin"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/projects/${var.project}/locations/${var.region}/workflows/${google_workflows_workflow.update_scrapaz_ip.name}/executions"
    headers = {
      "Content-Type" = "application/json"
    }
    oauth_token {
      service_account_email = local.workflow_service_account_email
    }
  }
}

# Outputs
output "workflow_service_account" {
  value = local.workflow_service_account_email
}

output "start_services_workflow" {
  value = google_workflows_workflow.start_services.name
}

output "stop_services_workflow" {
  value = google_workflows_workflow.stop_services.name
}

output "check_status_workflow" {
  value = google_workflows_workflow.check_services_status.name
}

output "update_scrapaz_ip_workflow" {
  value = google_workflows_workflow.update_scrapaz_ip.name
}

output "update_scrapaz_ip_scheduler" {
  value = var.enable_scheduled_start ? google_cloud_scheduler_job.update_scrapaz_ip_schedule[0].name : "Disabled"
}

output "usage_instructions" {
  value = <<-EOF
    Cloud Workflows have been created successfully!
    
    Workflows available:
    1. Start Services: ${google_workflows_workflow.start_services.name}
    2. Stop Services: ${google_workflows_workflow.stop_services.name}
    3. Check Status: ${google_workflows_workflow.check_services_status.name}
    4. Update Scrapaz IP: ${google_workflows_workflow.update_scrapaz_ip.name}
    
    To execute workflows manually:
    
    # Start services
    gcloud workflows execute ${google_workflows_workflow.start_services.name} --location=${var.region}
    
    # Stop services
    gcloud workflows execute ${google_workflows_workflow.stop_services.name} --location=${var.region}
    
    # Check status
    gcloud workflows execute ${google_workflows_workflow.check_services_status.name} --location=${var.region}

    # Update Scrapaz IP
    gcloud workflows execute ${google_workflows_workflow.update_scrapaz_ip.name} --location=${var.region}
    
    Scheduled jobs:
    - Start services: ${var.enable_scheduled_start ? "Enabled (Saturday 7 AM)" : "Disabled"}
    - Stop services: ${var.enable_scheduled_stop ? "Enabled (Sunday 7 PM)" : "Disabled"}
    
    Service Account: ${local.workflow_service_account_email}
  EOF
} 