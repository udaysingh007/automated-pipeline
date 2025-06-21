resource "null_resource" "generate_token" {
  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/users/${var.gitea_user}/tokens \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{"name": "argocd-access"}' \
        > ${path.module}/token.json
    EOT
  }

  triggers = {
    user = var.gitea_user
  }
}

data "local_file" "token_data" {
  filename = "${path.module}/token.json"
}

locals {
  gitea_token = jsondecode(data.local_file.token_data.content).sha1
}

output "gitea_token" {
  value     = local.gitea_token
  sensitive = true
}
