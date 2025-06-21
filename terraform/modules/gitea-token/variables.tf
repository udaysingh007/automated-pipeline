variable "gitea_user" {
  description = "Name of the gitea user"
  type        = string
}

variable "gitea_password" {
  description = "Password of the gitea user"
  type        = string
}

variable "gitea_base_url" {
  description = "Base url for the gitea server"
  type        = string
}

variable "repo_name" {
  description = "Name of the repo to be created"
  type        = string
}
