output "workflow_service_account_email" {
  description = "Email of the service account used by workflows"
  value       = local.workflow_service_account_email
}

output "start_services_workflow_name" {
  description = "Name of the workflow to start services"
  value       = google_workflows_workflow.start_services.name
}

output "stop_services_workflow_name" {
  description = "Name of the workflow to stop services"
  value       = google_workflows_workflow.stop_services.name
}

output "check_status_workflow_name" {
  description = "Name of the workflow to check service status"
  value       = google_workflows_workflow.check_services_status.name
}