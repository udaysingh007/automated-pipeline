module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"
  
  # Control plane gets access to all subnets
  subnet_ids = var.subnet_ids
  vpc_id     = var.vpc_id
  
  # Enable IRSA for service accounts
  enable_irsa = true
  
  # Control plane endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  
  # Manage aws-auth ConfigMap
  # manage_aws_auth_configmap = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-nodes"
      instance_types = [var.node_instance_type]
      
      # CRITICAL: Place worker nodes in PRIVATE subnets only
      subnet_ids = var.private_subnet_ids
      
      min_size     = 1
      max_size     = 3
      desired_size = var.desired_capacity
      
      # Enable cluster autoscaler tags
      labels = {
        Environment = "dev"
        NodeGroup   = "default"
      }
      
      tags = {
        "kubernetes.io/cluster-autoscaler/enabled" = "true"
        "kubernetes.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      }
    }
  }
  

  # Additional security group rules for communication
  cluster_security_group_additional_rules = {
    ingress_nodes_443 = {
      description                = "Node groups to cluster API"
      protocol                   = "tcp"
      from_port                  = 443
      to_port                    = 443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_cluster_443 = {
      description                   = "Cluster API to node groups"
      protocol                      = "tcp"
      from_port                     = 443
      to_port                       = 443
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_kubelet = {
      description                   = "Cluster API to node kubelets"
      protocol                      = "tcp"
      from_port                     = 10250
      to_port                       = 10250
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description = "Node all egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

