# --- 1. LOCAL CONFIGURATION (Simplified Variables) ---
locals {
  gcp_project_id = "[YOUR_PROJECT_ID]"
  gcp_region     = "us-central1"
  ar_repo        = "microservices-repo"
}

# --- 2. PROVIDERS ---
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.23" }
  }
}

provider "google" {
  project = local.gcp_project_id
  region  = local.gcp_region
}

# --- 3. GKE Cluster Creation ---

resource "google_container_cluster" "microservice_cluster" {
  name                     = "simple-app-cluster"
  location                 = local.gcp_region
  initial_node_count       = 1
  remove_default_node_pool = true
  
  node_pool {
    name = "default-pool"
    node_count = 1
    node_config {
      machine_type = "e2-small"
    }
  }
}

# --- 4. Kubernetes Provider Configuration ---
# Uses the cluster created above to deploy K8s resources
data "google_client_config" "default" {}

data "google_container_cluster" "cluster_data" {
  name     = google_container_cluster.microservice_cluster.name
  location = google_container_cluster.microservice_cluster.location
  depends_on = [google_container_cluster.microservice_cluster] 
}

provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.cluster_data.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.cluster_data.master_auth[0].cluster_ca_certificate)
}

# --- 5. KUBERNETES DEPLOYMENTS (The Containers) ---

# 5a. User Service Deployment
resource "kubernetes_deployment_v1" "user_deployment" {
  metadata { name = "user-service" }
  spec {
    replicas = "1"
    selector { match_labels = { app = "user-service" } }
    template {
      metadata { labels = { app = "user-service" } }
      spec {
        container {
          name  = "user-service-container"
          image = "${local.gcp_region}-docker.pkg.dev/${local.gcp_project_id}/${local.ar_repo}/user-service:v1"
          port { container_port = 3001 }
        }
      }
    }
  }
}

# 5b. Post Service Deployment
resource "kubernetes_deployment_v1" "post_deployment" {
  metadata { name = "post-service" }
  spec {
    replicas = "1"
    selector { match_labels = { app = "post-service" } }
    template {
      metadata { labels = { app = "post-service" } }
      spec {
        container {
          name  = "post-service-container"
          image = "${local.gcp_region}-docker.pkg.dev/${local.gcp_project_id}/${local.ar_repo}/post-service:v1"
          port { container_port = 3002 }
        }
      }
    }
  }
}


# --- 6. KUBERNETES SERVICES (External Links) ---

# 6a. User Service LoadBalancer
resource "kubernetes_service_v1" "user_service_external" {
  metadata { name = "user-service-external" }
  spec {
    selector = { app = "user-service" }
    port {
      port        = 3001 # External port (Public access via this port)
      target_port = 3001 # Internal container port
      protocol    = "TCP"
    }
    type = "LoadBalancer" # Creates a public IP on GCP
  }
}

# 6b. Post Service LoadBalancer
resource "kubernetes_service_v1" "post_service_external" {
  metadata { name = "post-service-external" }
  spec {
    selector = { app = "post-service" }
    port {
      port        = 3002 # External port (Public access via this port)
      target_port = 3002 # Internal container port
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}


# --- 7. OUTPUTS ---

output "user_service_ip_and_port" {
  value = "http://${kubernetes_service_v1.user_service_external.status[0].load_balancer[0].ingress[0].ip}:3001"
  description = "Access URL for User Service."
}

output "post_service_ip_and_port" {
  value = "http://${kubernetes_service_v1.post_service_lb.status[0].load_balancer[0].ingress[0].ip}:3002"
  description = "Access URL for Post Service."
}