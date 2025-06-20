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
  source             = "./modules/eks"
  vpc_id             = module.vpc.vpc_id
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

# provider "kubernetes" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_ca)
#   token                  = data.aws_eks_cluster_auth.cluster.token
# }

# provider "helm" {
#   alias = "eks"

#   kubernetes {
#     host                   = module.eks.cluster_endpoint
#     cluster_ca_certificate = base64decode(module.eks.cluster_ca)
#     token                  = data.aws_eks_cluster_auth.cluster.token
#   }
# }

module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.eks]
}

data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [module.argocd]
}

resource "helm_release" "gitea" {
  name             = "gitea"
  namespace        = "gitea"
  create_namespace = true
  repository       = "https://dl.gitea.io/charts/"
  chart            = "gitea"
  version          = "10.1.1"
  values = [<<EOF
postgresql:
  enabled: true
postgresql-ha:
  enabled: false
service:
  http:
    type: LoadBalancer
EOF
  ]
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
