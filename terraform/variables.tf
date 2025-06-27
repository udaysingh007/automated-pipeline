variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "pipeline-sandbox"
}

variable "ecr_repo_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "pipeline-sandbox-ecr"
}

variable "gitea_repo_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "gitea-repo1"
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "stage", "prod"], var.environment)
    error_message = "Environment must be dev, stage, or prod"
  }
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
  default     = "admin0007"
}

variable "postgres_password" {
  description = "Password for PostgreSQL database"
  type        = string
  sensitive   = true
  default     = "admin0007"
}

variable "target_node_name" {
  description = "Target node name where local storage PVs are located"
  type        = string
  default     = "node-with-pv"
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "aws_creds_secret_name" {
  description = "Kubernetes secret name that stores AWS credentials"
  type        = string
  default     = "aws-creds"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)

  default = {
    pkg = "pipeline-sandbox"
    env = "dev"
  }
}

variable "webhook_token" {
  description = "Custom webhook token (optional - will generate if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}
