###################################################################
#
# launching the entire automated pipeline sandbox environment
#
###################################################################
module "vpc" {
  source = "./modules/vpc"
}

module "eks" {
  source             = "./modules/eks"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  cluster_name       = var.cluster_name
  node_instance_type = var.node_instance_type
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  alias = "eks"

  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

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
service:
  http:
    type: NodePort
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
  serviceType: NodePort
EOF
  ]
  depends_on = [module.eks]
}

resource "helm_release" "argo_events" {
  name       = "argo-events"
  namespace  = "argo"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = "2.5.4"
  values = [<<EOF
webhook:
  service:
    type: NodePort
EOF
  ]
  depends_on = [module.eks, helm_release.argo_workflows]
}

