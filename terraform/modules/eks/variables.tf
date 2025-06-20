variable "vpc_id" {}

variable "subnet_ids" { type = list(string) }

variable "cluster_name" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "desired_capacity" {
  type = number
  default = 3
}
