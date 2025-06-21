# ==============================================================================
# FILE: modules/gitea/variables.tf
# ==============================================================================

variable "namespace" {
  description = "Kubernetes namespace for Gitea deployment"
  type        = string
  default     = "gitea"
}

variable "release_name" {
  description = "Helm release name for Gitea"
  type        = string
  default     = "gitea"
}

variable "chart_version" {
  description = "Gitea Helm chart version"
  type        = string
  default     = "10.1.4"
}

variable "admin_username" {
  description = "Gitea admin username"
  type        = string
  default     = "administrator001"
}

variable "admin_password" {
  description = "Gitea admin password"
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Gitea admin email"
  type        = string
  default     = "administrator001@example.com"
}

variable "domain" {
  description = "Domain name for Gitea"
  type        = string
  default     = "gitea.local"
}

variable "root_url" {
  description = "Root URL for Gitea"
  type        = string
  default     = "http://gitea.local"
}

variable "postgres_username" {
  description = "PostgreSQL username"
  type        = string
  default     = "gitea"
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  default     = "gitea"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "local-fast"
}

variable "gitea_pv_size" {
  description = "Size of Gitea persistent volume"
  type        = string
  default     = "20Gi"
}

variable "postgres_pv_size" {
  description = "Size of PostgreSQL persistent volume"
  type        = string
  default     = "10Gi"
}

variable "service_type" {
  description = "Kubernetes service type for Gitea"
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.service_type)
    error_message = "Service type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "ingress_enabled" {
  description = "Enable ingress for Gitea"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "resource_limits_cpu" {
  description = "CPU resource limits for Gitea pods"
  type        = string
  default     = "1000m"
}

variable "resource_limits_memory" {
  description = "Memory resource limits for Gitea pods"
  type        = string
  default     = "1Gi"
}

variable "resource_requests_cpu" {
  description = "CPU resource requests for Gitea pods"
  type        = string
  default     = "100m"
}

variable "resource_requests_memory" {
  description = "Memory resource requests for Gitea pods"
  type        = string
  default     = "128Mi"
}

# variable "node_selector" {
#   description = "Node selector for Gitea pods"
#   type        = map(string)
#   default     = {}
# }

# variable "tolerations" {
#   description = "Tolerations for Gitea pods"
#   type        = list(object({
#     key      = string
#     operator = string
#     value    = string
#     effect   = string
#   }))
#   default = []
# }

