
variable "credentials" {
  description = "My Credentials"
  default     = "../.google/niblr-terra-airflow.json"
}


variable "project" {
  description = "Project"
  default     = "niblr-agentic-service"
}

variable "region" {
  description = "Region"
  default     = "europe-west3"
}

variable "zone" {
    description = "Zone"
    default = "europe-west3-a"
}

variable "image" {
    description = "Machine Image"
    default = "ubuntu-2004-focal-v20250111"
}

variable "user"{
    description = "User for maching"
    default = "ahsnl_mi"
}

variable "ssh_key_file" {
  description = "Path to the SSH public key file"
  default     = "~/.ssh/gcp_key.pub" 

}