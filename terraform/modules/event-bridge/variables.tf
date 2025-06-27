variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "AWS EKS cluster name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "aws_creds_secret_name" {
  description = "Kubernetes secret name that stores AWS credentials"
  type        = string
}

variable "argo_namespace" {
  type        = string
  description = "argo namespace"
  default     = "argo"
}

variable "target_node_host_path" {
  type        = string
  description = "This is the host name of node where host path will be mounted as a way to get poor man's PVC"
}

variable "repo_name" {
  type        = string
  description = "The name of the Gitea repo"
}

variable "ecr_repo_url" {
  type        = string
  description = "ECR repository URL"
}

