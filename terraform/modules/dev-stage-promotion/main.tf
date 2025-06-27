# file.tf - Terraform module for webhook-based dev to stage promotion system

variable "namespace" {
  description = "Kubernetes namespace for Argo Events"
  type        = string
  default     = "argo-events"
}

variable "target_node_host_path" {
  description = "Target node hostname for workflow execution"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "webhook_token" {
  description = "Security token for webhook authentication"
  type        = string
  sensitive   = true
}

# Generate a random webhook token if not provided
resource "random_password" "webhook_token" {
  count   = var.webhook_token == "" ? 1 : 0
  length  = 32
  special = true
}

locals {
  webhook_token = var.webhook_token != "" ? var.webhook_token : random_password.webhook_token[0].result
  
  # Template variables for YAML files
  template_vars = {
    namespace             = var.namespace
    webhook_secret_name   = kubernetes_secret.webhook_secret.metadata[0].name
    target_node_host_path = var.target_node_host_path
    ecr_repo_url         = var.ecr_repo_url
    region               = var.region
  }
}

# Secret for webhook authentication
resource "kubernetes_secret" "webhook_secret" {
  metadata {
    name      = "webhook-secret"
    namespace = var.namespace
  }

  data = {
    token = local.webhook_token
  }

  type = "Opaque"
}

# EventSource for webhook using external YAML template
resource "kubernetes_manifest" "webhook_eventsource" {
  manifest = yamldecode(templatefile("${path.module}/eventsource.yaml", local.template_vars))
  
  depends_on = [
    kubernetes_secret.webhook_secret
  ]
}

# Service for webhook EventSource
resource "kubernetes_service" "webhook_eventsource_svc" {
  metadata {
    name      = "webhook-eventsource-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      "eventsource-name" = "webhook-eventsource"
    }

    port {
      port        = 12000
      target_port = 12000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Sensor for dev to stage promotion workflow using external YAML template
resource "kubernetes_manifest" "dev_stage_promotion_sensor" {
  manifest = yamldecode(templatefile("${path.module}/sensor.yaml", local.template_vars))

  depends_on = [
    kubernetes_manifest.webhook_eventsource,
    kubernetes_secret.webhook_secret
  ]
}

# Output the webhook URL and token for reference
output "webhook_url" {
  description = "URL to call to trigger the dev to stage promotion workflow"
  value       = "http://webhook-eventsource-svc.${var.namespace}.svc.cluster.local:12000/webhook"
}

output "webhook_token" {
  description = "Authentication token for webhook calls"
  value       = local.webhook_token
  sensitive   = true
}

output "webhook_service_name" {
  description = "Name of the webhook service"
  value       = kubernetes_service.webhook_eventsource_svc.metadata[0].name
}