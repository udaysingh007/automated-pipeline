# ==============================================================================
# FILE: modules/gitea/main.tf
# ==============================================================================

# Create namespace for Gitea
resource "kubernetes_namespace" "gitea" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
      app  = "gitea"
    }
  }
}

# Create secret for Gitea admin credentials
resource "kubernetes_secret" "gitea_admin" {
  metadata {
    name      = "gitea-admin-secret"
    namespace = kubernetes_namespace.gitea.metadata[0].name
  }

  data = {
    username = var.admin_username
    password = var.admin_password
    email    = var.admin_email
  }

  type = "Opaque"
}

# Create secret for PostgreSQL credentials
resource "kubernetes_secret" "postgres_auth" {
  metadata {
    name      = "postgres-auth-secret"
    namespace = kubernetes_namespace.gitea.metadata[0].name
  }

  data = {
    username = var.postgres_username
    password = var.postgres_password
    database = var.postgres_database
  }

  type = "Opaque"
}

# Generate secure secret key for Gitea
resource "random_password" "gitea_secret_key" {
  length  = 64
  special = true
}

# Helm release for Gitea
resource "helm_release" "gitea" {
  name       = var.release_name
  repository = "https://dl.gitea.io/charts/"
  chart      = "gitea"
  version    = var.chart_version
  namespace  = kubernetes_namespace.gitea.metadata[0].name

  # Use the values.yaml template
  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      admin_username     = var.admin_username
      admin_password     = var.admin_password
      admin_email        = var.admin_email
      domain            = var.domain
      root_url          = var.root_url
      postgres_username = var.postgres_username
      postgres_password = var.postgres_password
      postgres_database = var.postgres_database
      secret_key        = random_password.gitea_secret_key.result
      service_type      = var.service_type
      ingress_enabled   = var.ingress_enabled
      ingress_class     = var.ingress_class
      resource_limits_cpu    = var.resource_limits_cpu
      resource_limits_memory = var.resource_limits_memory
      resource_requests_cpu    = var.resource_requests_cpu
      resource_requests_memory = var.resource_requests_memory
      release_name      = var.release_name
    #   node_selector     = var.node_selector
    })
  ]

  depends_on = [
    kubernetes_namespace.gitea,
    kubernetes_secret.gitea_admin,
    kubernetes_secret.postgres_auth
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600
}
