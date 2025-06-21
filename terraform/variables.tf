variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "pipeline-sandbox"
}

variable "node_instance_type" {
  default = "t3.medium"
}

variable "desired_capacity" {
  description = "Name of the EKS cluster"
  type        = number
  default     = 3
}

variable "gitea_admin_password" {
  description = "Password for Gitea admin user"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "target_node_name" {
  description = "Target node name where local storage PVs are located"
  type        = string
  default     = "node-with-pv"
}
