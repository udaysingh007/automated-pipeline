###################################################################
#
# launching the entire automated pipeline sandbox environment.
#
###################################################################
# providers
provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# resources and modules
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

module "ecr" {
  source        = "./modules/ecr"
  ecr_repo_name = var.ecr_repo_name
  environment   = var.environment
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# Data source to get all nodes
data "kubernetes_nodes" "all" {}

# Local value to get the first node's hostname label
locals {
  target_node_for_host_path = data.kubernetes_nodes.all.nodes[0].metadata[0].labels["kubernetes.io/hostname"]
  target_node_for_ebus = data.kubernetes_nodes.all.nodes[1].metadata[0].labels["kubernetes.io/hostname"]
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

  depends_on = [module.argocd]
}

resource "helm_release" "argo_workflows" {
  depends_on = [module.argocd]

  name             = "argo-workflows"
  namespace        = "argo"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = "0.41.4"

  values = [<<EOF
server:
  # Use LoadBalancer for external access
  serviceType: LoadBalancer
  
  # Disable authentication (note: plural "authModes")
  authModes: []
  
  # Disable secure mode for easier access
  secure: false
  
  # Optional: Set specific service annotations for cloud provider
  # serviceAnnotations:
  #   service.beta.kubernetes.io/aws-load-balancer-type: "nlb"

# Create a service account with proper permissions for workflow execution
serviceAccount:
  create: true
  name: "argo-workflows-server"

# Enable workflow controller
controller:
  enabled: true

  # ✅ Set default service account for all workflows
  workflowDefaults:
    spec:
      serviceAccountName: argo-workflows-server

# Create RBAC resources
createAggregateRoles: true
EOF
  ]
}

resource "kubernetes_cluster_role" "argo_workflows_full_access" {
  metadata {
    name = "argo-workflows-full-access"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "configmaps"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }

  rule {
    api_groups = ["argoproj.io"]
    resources = [
      "workflows",
      "workflowtemplates",
      "cronworkflows",
      "workflowtaskresults"
    ]
    verbs = ["*"]
  }
}

resource "kubernetes_cluster_role_binding" "argo_workflows_binding" {
  metadata {
    name = "argo-workflows-server-full-access"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.argo_workflows_full_access.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argo-workflows-server"
    namespace = "argo"
  }
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
  depends_on = [helm_release.argo_workflows]
}

module "ebus" {
  source = "./modules/event-bus"
  namespace    = "argo"
  node_selector_value = local.target_node_for_ebus

  depends_on = [helm_release.argo_events]
}


# setup aws credentials as EKS secrets
resource "kubernetes_secret" "aws_creds" {
  metadata {
    name      = var.aws_creds_secret_name
    namespace = "argo"
  }

  data = {
    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
  }

  type = "Opaque"

  depends_on = [module.argocd]
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

data "kubernetes_service" "gitea_http" {
  metadata {
    name      = "gitea-http"
    namespace = module.gitea.namespace
  }

  depends_on = [module.gitea]
}

locals {
  gitea_ingress = try(
    data.kubernetes_service.gitea_http.status[0].load_balancer[0].ingress[0],
    null
  )

  gitea_host = try(
    local.gitea_ingress.hostname,
    local.gitea_ingress.ip,
    null
  )

  gitea_base_url = local.gitea_host != null ? "http://${local.gitea_host}:3000" : null
}

module "gitea_repo" {
  source         = "./modules/gitea-repo"
  gitea_user     = module.gitea.admin_username
  gitea_password = var.gitea_admin_password
  gitea_base_url = local.gitea_base_url
  repo_name      = var.gitea_repo_name

  depends_on = [data.kubernetes_service.gitea_http]
}

module "gitea_token" {
  source         = "./modules/gitea-token"
  gitea_user     = module.gitea.admin_username
  gitea_password = var.gitea_admin_password
  gitea_base_url = local.gitea_base_url
  repo_name      = var.gitea_repo_name

  depends_on = [module.gitea_repo]
}

module "argocd_secret" {
  source         = "./modules/argo-secrets"
  gitea_user     = module.gitea.admin_username
  gitea_token    = module.gitea_token.gitea_token
  gitea_base_url = local.gitea_base_url
  repo_user      = module.gitea.admin_username
  repo_name      = var.gitea_repo_name

  depends_on = [module.gitea_token]
}

module "argocd_app" {
  source         = "./modules/argo-application"
  gitea_user     = module.gitea.admin_username
  gitea_token    = module.gitea_token.gitea_token
  gitea_base_url = local.gitea_base_url
  repo_user      = module.gitea.admin_username
  repo_name      = var.gitea_repo_name

  depends_on = [module.argocd]
}

# install the webhook in gitea for the repo, so that it can invoke teh
# Event Source service for gitea (that we deployed as part of argo_events)
# and that will invoke the associated Sensor which will launch the workflow 
# to git-clone and build and push image
module "argo_build_workflow" {
  source                = "./modules/argo-events"
  gitea_user            = module.gitea.admin_username
  gitea_token           = module.gitea_token.gitea_token
  gitea_base_url        = local.gitea_base_url
  repo_name             = var.gitea_repo_name
  aws_region            = var.region
  ecr_repo_url          = module.ecr.ecr_repository_url
  target_node_host_path = local.target_node_for_host_path

  depends_on = [module.argocd_app]
}

module "build_test_retag_workflow_v1" {
  source                = "./modules/argo-workflows"
  gitea_base_url        = local.gitea_base_url
  gitea_user            = module.gitea.admin_username
  repo_name             = var.gitea_repo_name
  ecr_repo_url          = module.ecr.ecr_repository_url
  aws_region            = var.region
  image_tag             = "v1.0.0"
  target_node_host_path = local.target_node_for_host_path

  depends_on = [module.argo_build_workflow]
}

module "ecr_event_bridge_to_argoworkflow" {
  source                = "./modules/event-bridge"
  ecr_repo_name         = var.ecr_repo_name
  aws_region            = var.region
  aws_creds_secret_name = var.aws_creds_secret_name
  tags                  = var.tags

  depends_on = [module.build_test_retag_workflow_v1]
}
