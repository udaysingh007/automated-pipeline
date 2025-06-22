variable "gitea_base_url" {
  type        = string
  description = "Base URL for the Gitea server, e.g., http://gitea.local"
}

variable "repo_name" {
  type        = string
  description = "The name of the Gitea repo"
}

variable "gitea_user" {
  type        = string
  description = "Gitea username"
}

variable "ecr_repo_url" {
  type        = string
  description = "ECR repository URL"
}

variable "aws_region" {
  type        = string
  description = "AWS region where ECR is hosted"
}

variable "image_tag" {
  type        = string
  default     = "v1.0.0"
  description = "Docker image tag to retag after tests pass"
}

