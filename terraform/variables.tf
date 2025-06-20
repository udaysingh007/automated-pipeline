variable "aws_region" {
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
