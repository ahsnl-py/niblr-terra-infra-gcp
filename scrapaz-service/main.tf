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

# Read in script file and service account
locals {
  script_content = file("../Install_docker.sh")
  gsc_service_acct = file("../.google/credentials/sa-niblr-airflow.json")
  gsc_service_acct_base64 = base64encode(file("../.google/credentials/sa-niblr-airflow.json"))
}

# Create GCP firewall rule to allow HTTP traffic on port 8001
resource "google_compute_firewall" "scrapaz_firewall" {
  name    = "scrapaz-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8001"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["scrapaz-service"]
  description   = "Allow scrapaz service on ports 80, 443, and 8001"
}

# Create the VM instance for scrapaz service
resource "google_compute_instance" "scrapaz_instance" {
  name         = "scrapaz-service-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  tags = ["scrapaz-service"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-focal-v20240307b"
      size  = 30  # Increased disk size for Docker and dependencies
    }
  }

  network_interface {
    network = "default"
    access_config {
      // This will assign a public IP
    }
  }

  metadata = {
    ssh-keys = "${var.user}:${file(var.ssh_key_file)}"
    user-data = <<-EOF
      #!/bin/bash
      
      # Update system
      sudo apt-get update -y
      
      # Install Docker
      echo '${local.script_content}' > /tmp/install_docker.sh
      chmod +x /tmp/install_docker.sh
      bash /tmp/install_docker.sh

      # Create user directory and setup
      sudo mkdir -p /home/${var.user}/.google/credentials
      chmod -R 755 /home/${var.user}/.google

      # Clone the scrapaz repository
      cd /home/${var.user}
      git clone https://github.com/ahsnl-py/scrapaz-web-crawler.git
      cd scrapaz-web-crawler

      # Setup Google credentials
      sudo mkdir -p .google/credentials
      chmod -R 755 .google
      echo '${local.gsc_service_acct}' > .google/credentials/google_credentials.json

      # Create environment file for API keys
      cat > .env << 'ENVEOF'
      GROQ_API_KEY=${var.groq_api_key}
      ENVEOF

      # Add user to docker group
      sudo usermod -aG docker ${var.user}
      newgrp docker

      # Build and run the Docker container
      docker build -t scrapaz-service .
      
      # Run the service on port 8001 (as per docker-compose.yml)
      docker run -d \
        --name scrapaz-service \
        --restart unless-stopped \
        -p 8001:8001 \
        --env-file .env \
        -v /home/${var.user}/scrapaz-web-crawler/data:/app/data \
        scrapaz-service

      # Install nginx for reverse proxy (optional)
      sudo apt-get install -y nginx
      sudo systemctl enable nginx
      sudo systemctl start nginx

      # Configure nginx to proxy to the FastAPI service
      sudo tee /etc/nginx/sites-available/scrapaz << 'NGINXEOF'
      server {
          listen 80;
          server_name _;

          location / {
              proxy_pass http://localhost:8001;
              proxy_set_header Host \$host;
              proxy_set_header X-Real-IP \$remote_addr;
              proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto \$scheme;
          }
      }
      NGINXEOF

      sudo ln -sf /etc/nginx/sites-available/scrapaz /etc/nginx/sites-enabled/
      sudo rm -f /etc/nginx/sites-enabled/default
      sudo nginx -t && sudo systemctl reload nginx

      # Create a simple health check script
      cat > /home/${var.user}/health_check.sh << 'HEALTHEOF'
      #!/bin/bash
      curl -f http://localhost:8001/health || exit 1
      HEALTHEOF
      chmod +x /home/${var.user}/health_check.sh

      echo "Scrapaz service deployment completed at $(date)" > /home/${var.user}/deployment.log
    EOF
  }

  # Allow the instance to stop for update
  allow_stopping_for_update = true
}

# Load balancer components removed for testing - uncomment for production
# resource "google_compute_global_forwarding_rule" "scrapaz_lb" {
#   name       = "scrapaz-load-balancer"
#   target     = google_compute_target_http_proxy.scrapaz_proxy.id
#   port_range = "80"
# }

# resource "google_compute_target_http_proxy" "scrapaz_proxy" {
#   name    = "scrapaz-http-proxy"
#   url_map = google_compute_url_map.scrapaz_url_map.id
# }

# resource "google_compute_url_map" "scrapaz_url_map" {
#   name            = "scrapaz-url-map"
#   default_service = google_compute_backend_service.scrapaz_backend.id
# }

# resource "google_compute_backend_service" "scrapaz_backend" {
#   name        = "scrapaz-backend"
#   protocol    = "HTTP"
#   port_name   = "http"
#   timeout_sec = 10

#   backend {
#     group = google_compute_instance_group.scrapaz_group.id
#   }

#   health_checks = [google_compute_health_check.scrapaz_health_check.id]
# }

# resource "google_compute_instance_group" "scrapaz_group" {
#   name      = "scrapaz-instance-group"
#   zone      = var.zone
#   instances = [google_compute_instance.scrapaz_instance.self_link]

#   named_port {
#     name = "http"
#     port = 8001
#   }
# }

# resource "google_compute_health_check" "scrapaz_health_check" {
#   name = "scrapaz-health-check"

#   http_health_check {
#     port = 8001
#     request_path = "/health"
#   }
# }

# Outputs
output "scrapaz_public_ip" {
  value = google_compute_instance.scrapaz_instance.network_interface[0].access_config[0].nat_ip
}

output "scrapaz_service_url" {
  value = "http://${google_compute_instance.scrapaz_instance.network_interface[0].access_config[0].nat_ip}"
}

# Load balancer output removed for testing
# output "scrapaz_load_balancer_ip" {
#   value = google_compute_global_forwarding_rule.scrapaz_lb.ip_address
# }

output "deployment_instructions" {
  value = <<-EOF
    Scrapaz service has been deployed!
    
    Direct VM access: http://${google_compute_instance.scrapaz_instance.network_interface[0].access_config[0].nat_ip}:8001
    Nginx proxy: http://${google_compute_instance.scrapaz_instance.network_interface[0].access_config[0].nat_ip}
    
    SSH to VM: ssh -i ${var.ssh_key_file} ${var.user}@${google_compute_instance.scrapaz_instance.network_interface[0].access_config[0].nat_ip}
    
    Check service status: docker ps
    View logs: docker logs scrapaz-service
    
    Note: Load balancer disabled for testing. Enable in main.tf for production.
  EOF
}
