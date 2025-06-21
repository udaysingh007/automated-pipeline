resource "null_resource" "create_repo" {
  provisioner "local-exec" {
    command = <<EOT
      curl -X POST ${var.gitea_base_url}/api/v1/user/repos \
        -u ${var.gitea_user}:${var.gitea_password} \
        -H 'Content-Type: application/json' \
        -d '{"name": "${var.repo_name}"}'
    EOT
  }
}
