terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70" # Pin to a specific 5.x version
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    null = {
      source = "hashicorp/null"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.0"
#     }
#     helm = {
#       source  = "hashicorp/helm"
#       version = "~> 2.13" # or latest tested version
#     }
#     kubernetes = {
#       source  = "hashicorp/kubernetes"
#       version = "~> 2.27"
#     }
#   }
# }


provider "aws" {
  region = var.region
}
