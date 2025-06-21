resource "kubernetes_secret" "argocd_gitea_repo" {
  metadata {
    name      = "gitea-repo-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  type = "Opaque"

  data = {
    url      = base64encode("https://${var.gitea_base_url}/${var.repo_user}/${var.repo_name}.git")
    username = base64encode(var.gitea_user)
    password = base64encode(var.gitea_token)
  }

}
