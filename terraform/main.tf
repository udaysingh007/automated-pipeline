###################################################################
#
# launching the entire automated pipeline sandbox environment.
#
###################################################################
module "vpc" {
  source       = "./modules/vpc"
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"
  vpc_id = module.vpc.vpc_id
  # CRITICAL FIX: Use ALL subnets (public + private) for control plane
  # but worker nodes will be placed in private subnets
  subnet_ids         = module.vpc.all_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_name       = var.cluster_name
  node_instance_type = var.node_instance_type
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.eks]
}

# Get available nodes for node selector
data "kubernetes_nodes" "available" {
  depends_on = [module.eks]
}

# Deploy Gitea using the module
module "gitea" {
  source = "./modules/gitea"

  # Basic configuration
  namespace    = "gitea"
  release_name = "gitea"

  # Admin credentials - use secure values!
  admin_username = "administrator001"
  admin_password = var.gitea_admin_password # Define this in terraform.tfvars
  admin_email    = "admin@yourdomain.com"

  # Database credentials - use secure values!
  postgres_username = "gitea"
  postgres_password = var.postgres_password # Define this in terraform.tfvars
  postgres_database = "gitea"

  # Network configuration
  domain       = "gitea.local"        # Update with your actual domain
  root_url     = "http://gitea.local" # Update with your actual URL
  service_type = "LoadBalancer"       # Change to LoadBalancer if you have external LB

  # Storage configuration - matches your existing PVs
  storage_class    = "local-fast"
  gitea_pv_size    = "20Gi"
  postgres_pv_size = "10Gi"

  # Ingress configuration (enable if you have ingress controller)
  ingress_enabled = false
  ingress_class   = "nginx"

  # Resource configuration
  resource_limits_cpu      = "1000m"
  resource_limits_memory   = "1Gi"
  resource_requests_cpu    = "100m"
  resource_requests_memory = "128Mi"

  depends_on = [module.eks]
}

resource "helm_release" "argo_workflows" {
  name             = "argo-workflows"
  namespace        = "argo"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = "0.41.4"
  values = [<<EOF
server:
  serviceType: LoadBalancer
EOF
  ]
  depends_on = [module.eks]
}

resource "helm_release" "argo_events" {
  name       = "argo-events"
  namespace  = "argo"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = "2.4.15"
  values = [<<EOF
webhook:
  service:
    type: LoadBalancer
EOF
  ]
  depends_on = [module.eks, helm_release.argo_workflows]
}

resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = <<EOT
aws eks update-kubeconfig \
  --region ${var.region} \
  --name ${module.eks.cluster_name} \
  --alias ${module.eks.cluster_name}
EOT
  }
}
