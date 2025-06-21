terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

variable "gitea_base_url" {
  type        = string
  description = "Base URL for the Gitea server, e.g., http://gitea.local"
}

variable "gitea_webhook_url" {
  type        = string
  description = "Push URL for Argo Events webhook listener"
}

variable "repo_name" {
  type        = string
  description = "The name of the Gitea repo"
}

variable "gitea_user" {
  type        = string
  description = "Gitea username"
}

variable "gitea_token" {
  type        = string
  description = "Gitea TOKEN"
}

variable "ecr_repo_url" {
  type        = string
  description = "ECR repository URL"
}

variable "aws_region" {
  type        = string
  description = "AWS region where ECR is hosted"
}

resource "kubectl_manifest" "event_source" {
  yaml_body = templatefile("${path.module}/event-source.yaml.tmpl", {
    webhook_url = var.gitea_webhook_url
  })
}

resource "kubectl_manifest" "sensor" {
  yaml_body = file("${path.module}/sensor.yaml")
}

resource "kubectl_manifest" "workflow_template" {
  yaml_body = templatefile("${path.module}/workflow.yaml.tmpl", {
    repo_url     = "${var.gitea_base_url}/${var.gitea_user}/${var.repo_name}.git",
    ecr_repo_url = var.ecr_repo_url,
    region       = var.aws_region
  })
}

resource "null_resource" "create_gitea_webhook" {
  provisioner "local-exec" {
    command = <<EOT
    curl -s -X POST \
      -u "${var.gitea_user}:${var.gitea_token}" \
      -H 'Content-Type: application/json' \
      -d '{
        "type": "gitea",
        "config": {
          "url": "${var.gitea_webhook_url}",
          "content_type": "json"
        },
        "events": ["push"],
        "active": true
      }' \
      ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/hooks
    EOT
  }
  triggers = {
    repo = var.repo_name
  }
}  

templatefile("modules/argo-events/workflow.yaml.tmpl", {repo_url     = "https://gitea.example.com/user/repo.git", ecr_repo_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/my-repo",region       = "us-east-1"})
