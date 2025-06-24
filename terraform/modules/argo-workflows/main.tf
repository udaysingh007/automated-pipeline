terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
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
resource "kubectl_manifest" "build_test_retag_workflow" {
  yaml_body = templatefile("${path.module}/build-test-retag.yaml.tmpl", {
    namespace             = var.argo_namespace
    target_node_host_path = var.target_node_host_path
    repo_url              = "${var.gitea_base_url}/${var.gitea_user}/${var.repo_name}.git",
    ecr_repo_url          = var.ecr_repo_url
    region                = var.aws_region
    tag                   = var.image_tag
  })
}
