variable "gitea_user" {
  description = "Name of the gitea user"
  type        = string
}

variable "gitea_token" {
  description = "Token of the gitea user"
  type        = string
}

variable "gitea_base_url" {
  description = "Base url for the gitea server"
  type        = string
}

variable "repo_user" {
  description = "User name that creatd the repo"
  type        = string
}

variable "repo_name" {
  description = "Name of the repo to be created"
  type        = string
}
