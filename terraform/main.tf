# terraform/main.tf
terraform {
  required_version = ">= 1.0"
 required_providers {
 
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
      null = {
      source  = "hashicorp/null"
      version = "~> 3.2.1"
    }
  
  }
}

# For local development with minikube
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Local values
locals {
  cluster_name = "minikube-cluster-${var.environment}"
}
# Minikube cluster creation
resource "null_resource" "minikube_cluster" {
  triggers = {
    environment    = var.environment
    minikube_cpu   = var.minikube_cpu
    minikube_memory = var.minikube_memory
    timestamp      = timestamp()
  }
 # Create minikube cluster with specific profile
  provisioner "local-exec" {
    command = <<EOT
      minikube start \
        --driver=docker \
        --cpus=${var.minikube_cpu} \
        --memory=${var.minikube_memory} \
        --profile=${local.cluster_name} \
        --addons=ingress \
        --addons=metrics-server
    EOT
  }

   
  # Update context after creation
  provisioner "local-exec" {
    command = "minikube update-context --profile=${local.cluster_name}"
  }

  # FIXED: Delete the correct cluster by profile name
  provisioner "local-exec" {
    when    = destroy
    command = "minikube delete --profile=${self.triggers.cluster_name}"
  }
}
