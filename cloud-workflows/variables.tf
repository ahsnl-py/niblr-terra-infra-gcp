variable "credentials" {
  description = "Path to Google Cloud service account credentials file"
  default     = "../.google/credentials/sa-cloud-workflow.json"
}

variable "project" {
  description = "Google Cloud project ID"
  default     = "niblr-agentic-service"
}

variable "region" {
  description = "Google Cloud region"
  default     = "europe-west3"
}

variable "zone" {
  description = "Google Cloud zone"
  default     = "europe-west3-a"
}

variable "enable_scheduled_start" {
  description = "Enable scheduled start of services"
  type        = bool
  default     = true
}

variable "enable_scheduled_stop" {
  description = "Enable scheduled stop of services"
  type        = bool
  default     = true
}

variable "start_schedule" {
  description = "Cron schedule for starting services (default: Saturday at 7 AM)"
  default     = "0 7 * * 6"
}

variable "stop_schedule" {
  description = "Cron schedule for stopping services (default: Sunday at 7 PM)"
  default     = "0 19 * * 0"
}
