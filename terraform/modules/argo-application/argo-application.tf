resource "kubernetes_manifest" "gitea_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "go-app"
      namespace = "argocd"
    }
    spec = {
      source = {
        repoURL        = "https://${var.gitea_base_url}/${var.repo_user}/${var.repo_name}.git"
        targetRevision = "HEAD"
        path           = "k8s/deploy"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "go-appp"
      }
      project = "default"
      syncPolicy = {
        automated = {
          selfHeal = true
          prune    = true
        }
      }
    }
  }
}
