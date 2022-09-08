variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

variable "gke_num_nodes" {
  default     = 2
  description = "number of gke nodes"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke2"
  location = var.region
  initial_node_count       = 2
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  remove_default_node_pool = true
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = "10.0.0.0/20"
  }
  networking_mode = "VPC_NATIVE"
  master_authorized_networks_config {
     cidr_blocks {
       cidr_block = "10.10.128.0/24"
       display_name = "internal"
     }
  }
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "10.11.0.0/28"
  }
  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }
  binary_authorization {
      evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.primary.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }
    # preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 10
    disk_type = "pd-standard"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "spot_nodes" {
  name       = "spot-nodepool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.project_id
    }

    spot = true
    machine_type = "n1-standard-1"
    disk_size_gb = 10
    disk_type = "pd-standard"
    tags         = ["gke-node", "${var.project_id}-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}