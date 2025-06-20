###################################################################
#
# launching the entire automated pipeline sandbox environment.
#
###################################################################
# VPC Module
module "vpc" {
  source       = "./modules/vpc"
  cluster_name = var.cluster_name
}

# EKS Module
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

# Get EKS cluster info for providers
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Configure Kubernetes Provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Configure Helm Provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# ArgoCD Module
module "argocd" {
  source     = "./modules/argocd"
  depends_on = [module.eks]
}

# Wait for ArgoCD to be ready before checking for nginx service
data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "nginx-ingress-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [module.argocd]
}

# Gitea Helm Release
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
    nodePort: 30080
ingress:
  enabled: false
persistence:
  enabled: true
  size: 10Gi
gitea:
  admin:
    username: gitea_admin
    password: admin123
    email: admin@gitea.local
EOF
  ]
  
  depends_on = [module.eks]
}

# Argo Workflows Helm Release
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
  serviceNodePort: 30081
  extraArgs:
    - --auth-mode=server
controller:
  workflowNamespaces:
    - argo
    - default
EOF
  ]
  
  depends_on = [module.eks]
}

# Argo Events Helm Release
resource "helm_release" "argo_events" {
  name             = "argo-events"
  namespace        = "argo"
  create_namespace = false  # namespace already created by argo-workflows
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  version          = "2.5.4"
  
  values = [<<EOF
webhook:
  service:
    type: NodePort
    nodePort: 30082
controller:
  replicas: 1
EOF
  ]
  
  depends_on = [module.eks, helm_release.argo_workflows]
}

# Update kubeconfig automatically
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = <<-EOF
      aws eks update-kubeconfig \
        --region ${var.aws_region} \
        --name ${var.cluster_name} \
        --alias ${var.cluster_name}
    EOF
  }

  depends_on = [module.eks]

  # Trigger update when cluster changes
  triggers = {
    cluster_name = module.eks.cluster_name
    endpoint     = data.aws_eks_cluster.cluster.endpoint
  }
}
