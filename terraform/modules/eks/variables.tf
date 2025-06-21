# Variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "All subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for worker nodes"
  type        = list(string)
}

variable "node_instance_type" {
  description = "Instance type for worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}


# Local storage specific variables
variable "local_storage_size" {
  description = "Size of additional EBS volume for local storage (in GB)"
  type        = number
  default     = 100
}

variable "num_general_pvs" {
  description = "Number of general-purpose local persistent volumes to create"
  type        = number
  default     = 5
}

variable "create_example_pvcs" {
  description = "Create example PVCs for testing (Gitea and Postgres)"
  type        = bool
  default     = true
}
