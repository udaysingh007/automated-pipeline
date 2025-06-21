# ==============================================================================
# FILE: modules/gitea/outputs.tf
# ==============================================================================

output "namespace" {
  description = "Namespace where Gitea is deployed"
  value       = kubernetes_namespace.gitea.metadata[0].name
}

output "release_name" {
  description = "Helm release name"
  value       = helm_release.gitea.name
}

output "service_name" {
  description = "Gitea service name"
  value       = "${var.release_name}-http"
}

output "admin_secret_name" {
  description = "Name of the admin credentials secret"
  value       = kubernetes_secret.gitea_admin.metadata[0].name
}

output "postgres_secret_name" {
  description = "Name of the PostgreSQL credentials secret"
  value       = kubernetes_secret.postgres_auth.metadata[0].name
}

output "gitea_url" {
  description = "Gitea URL"
  value       = var.root_url
}

output "admin_username" {
  description = "Gitea admin username"
  value       = var.admin_username
}
