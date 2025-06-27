terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

# provider "kubernetes" {
#   config_path = "~/.kube/config"
# }


variable "gitea_base_url" {
  type        = string
  description = "Base URL for the Gitea server, e.g., http://gitea.local"
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
    namespace = var.argo_namespace
  })
}

resource "kubectl_manifest" "sensor" {
  yaml_body = templatefile("${path.module}/sensor.yaml", {
    namespace             = var.argo_namespace
    target_node_host_path = var.target_node_host_path
    gitea_base_url        = var.gitea_base_url
    repo_url              = "${var.gitea_base_url}/${var.gitea_user}/${var.repo_name}.git",
    ecr_repo_url          = var.ecr_repo_url,
    region                = var.aws_region
  })
}

# Use null_resource to login to ECR and save Docker config
resource "null_resource" "ecr_docker_login" {
  provisioner "local-exec" {
    command = <<EOT
    aws ecr get-login-password --region ${var.aws_region} | \
    docker login --username AWS --password-stdin ${var.ecr_repo_url}
EOT
  }

  triggers = {
    login = "${timestamp()}" # re-run if you want to force
  }
}

# Read the config.json file after login
data "local_file" "docker_config" {
  depends_on = [null_resource.ecr_docker_login]
  filename   = pathexpand("~/.docker/config.json")
}

resource "kubernetes_secret" "kaniko_docker_config" {
  metadata {
    name      = "kaniko-docker-config"
    namespace = var.argo_namespace
  }

  data = {
    "config.json" = data.local_file.docker_config.content
  }

  type = "Opaque"
}


resource "kubectl_manifest" "workflow_template" {
  yaml_body = templatefile("${path.module}/workflow.yaml.tmpl", {
    namespace             = var.argo_namespace
    target_node_host_path = var.target_node_host_path
    repo_url              = "${var.gitea_base_url}/${var.gitea_user}/${var.repo_name}.git",
    ecr_repo_url          = var.ecr_repo_url,
    region                = var.aws_region
  })
}

resource "null_resource" "create_gitea_webhook" {
  provisioner "local-exec" {
    command = <<EOT
    response=$(curl -s -w "\n%%{http_code}" -X POST \
      -u "${var.gitea_user}:${var.gitea_token}" \
      -H 'Content-Type: application/json' \
      -d '{
        "type": "gitea",
        "config": {
          "url": "http://gitea-eventsource-svc.${var.argo_namespace}.svc.cluster.local:12000/push",
          "content_type": "json"
        },
        "events": ["push"],
        "active": true
      }' \
      ${var.gitea_base_url}/api/v1/repos/${var.gitea_user}/${var.repo_name}/hooks)
    
    echo "Response: $response"
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" -ne 201 ]; then
      echo "Failed to create webhook. HTTP code: $http_code"
      exit 1
    fi
    EOT
  }

  triggers = {
    repo = var.repo_name
    # Add more triggers to force recreation if needed
    webhook_url = "http://gitea-eventsource-svc.${var.argo_namespace}.svc.cluster.local:12000/push"
  }

  depends_on = [
    kubectl_manifest.event_source
  ]
}
