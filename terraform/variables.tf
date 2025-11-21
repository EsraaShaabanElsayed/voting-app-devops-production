variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
  default     = "myapp-cluster"
}

variable "node_count" {
  description = "Number of worker nodes"
  type        = map(number)
  default = {
    dev  = 2
    prod = 3
  }
}
variable "minikube_cpu" {
  description = "CPU allocation for minikube"
  type        = string
  default     = "2"
}
variable "minikube_memory" {
  description = "Memory allocation for minikube in MB"
  type        = string
  default     = "4096"
}
variable "cluster_name_prefix" {
  description = "Prefix for the cluster name"
  type        = string
  default     = "minikube-cluster-"
}