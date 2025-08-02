variable "credentials" {
  description = "Path to Google Cloud service account credentials file"
  default     = "../.google/niblr-terra-airflow.json"
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

variable "user" {
  description = "Username for the VM"
  default     = "ahsnl_mi"
}

variable "ssh_key_file" {
  description = "Path to the SSH public key file"
  default     = "~/.ssh/gcp_key.pub"
}

variable "groq_api_key" {
  description = "GROQ API key for the scrapaz service"
  type        = string
  sensitive   = true
}

variable "machine_type" {
  description = "Machine type for the VM"
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  default     = 30
} 