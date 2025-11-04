locals {
  project_id = "[YOUR_PROJECT_ID]"
  region     = "[YOUR_REGION]"
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = local.project_id
  region  = local.region
}

resource "google_container_cluster" "basic_cluster" {
  name                     = "minimal-gke-cluster"
  location                 = local.region
  remove_default_node_pool = true 
  initial_node_count       = 1

  node_pool {
    name       = "default-node-pool"
    node_count = 1
    node_config {
      machine_type = "e2-small"
    }
  }
}

output "cluster_name" {
  value = google_container_cluster.basic_cluster.name
}

output "cluster_endpoint" {
  value = google_container_cluster.basic_cluster.endpoint
}