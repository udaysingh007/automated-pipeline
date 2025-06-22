terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

resource "kubectl_manifest" "build_test_retag_workflow" {
  yaml_body = templatefile("${path.module}/build-test-retag.yaml.tmpl", {
    repo_url     = "${var.gitea_base_url}/${var.gitea_user}/${var.repo_name}.git",
    ecr_repo_url = var.ecr_repo_url
    region       = var.aws_region
    tag          = var.image_tag
  })
}
