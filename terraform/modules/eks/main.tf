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
  manage_aws_auth_configmap = true

  # EKS Managed Node Groups with additional storage
  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-nodes"
      instance_types = [var.node_instance_type]
      
      # CRITICAL: Place worker nodes in PRIVATE subnets only
      subnet_ids = var.private_subnet_ids
      
      min_size     = 1
      max_size     = 3
      desired_size = var.desired_capacity
      
      # Block device mapping for additional local storage
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
        # Additional volume for local storage
        xvdf = {
          device_name = "/dev/xvdf"
          ebs = {
            volume_size           = var.local_storage_size
            volume_type           = "gp3"
            iops                  = 3000
            throughput            = 125
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
      
      # Pre-bootstrap user data for setting up local storage
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        
        # Wait for device to be available
        while [ ! -b /dev/nvme2n1 ] && [ ! -b /dev/xvdf ]; do
          echo "Waiting for additional storage device..."
          sleep 5
        done
        
        # Determine the correct device name (depends on instance type)
        DEVICE=""
        if [ -b /dev/nvme2n1 ]; then
          DEVICE="/dev/nvme2n1"
        elif [ -b /dev/xvdf ]; then
          DEVICE="/dev/xvdf"
        fi
        
        if [ -n "$DEVICE" ]; then
          echo "Setting up local storage on $DEVICE"
          
          # Format the device
          mkfs.ext4 $DEVICE
          
          # Create mount point
          mkdir -p /mnt/local-storage
          
          # Mount the device
          mount $DEVICE /mnt/local-storage
          
          # Add to fstab for persistence
          echo "$DEVICE /mnt/local-storage ext4 defaults,nofail 0 2" >> /etc/fstab
          
          # Set permissions
          chmod 755 /mnt/local-storage
          
          # Create subdirectories for different use cases
          mkdir -p /mnt/local-storage/{gitea,postgres,redis,general}
          chmod 755 /mnt/local-storage/{gitea,postgres,redis,general}
          
          echo "Local storage setup completed on $DEVICE"
        else
          echo "No additional storage device found, creating local storage on root volume"
          mkdir -p /mnt/local-storage/{gitea,postgres,redis,general}
          chmod 755 /mnt/local-storage/{gitea,postgres,redis,general}
        fi
      EOT
      
      # Enable cluster autoscaler tags
      labels = {
        Environment = "sandbox"
        NodeGroup   = "default"
        StorageType = "local"
      }
      
      tags = {
        "kubernetes.io/cluster-autoscaler/enabled" = "true"
        "kubernetes.io/cluster-autoscaler/${var.cluster_name}" = "owned"
        "LocalStorage" = "enabled"
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
    Environment = "sandbox"
    Terraform   = "true"
    StorageType = "local"
  }
}

# =============================================================================
# LOCAL STORAGE CLASSES
# =============================================================================

# # Default local storage class for general use
# resource "kubernetes_storage_class_v1" "local_default" {
#   metadata {
#     name = "local-storage"
#     annotations = {
#       "storageclass.kubernetes.io/is-default-class" = "true"
#     }
#   }
  
#   storage_provisioner = "kubernetes.io/no-provisioner"
#   volume_binding_mode = "WaitForFirstConsumer"
#   reclaim_policy     = "Delete"
  
#   depends_on = [module.eks]
# }

# # Fast local storage class for high-performance apps
# resource "kubernetes_storage_class_v1" "local_fast" {
#   metadata {
#     name = "local-fast"
#   }
  
#   storage_provisioner = "kubernetes.io/no-provisioner"
#   volume_binding_mode = "WaitForFirstConsumer"
#   reclaim_policy     = "Delete"
  
#   depends_on = [module.eks]
# }

# # =============================================================================
# # LOCAL PERSISTENT VOLUMES
# # =============================================================================

# # Create local PVs for different use cases
# resource "kubernetes_persistent_volume_v1" "local_gitea_repos" {
#   metadata {
#     name = "local-gitea-repos"
#     labels = {
#       type = "local"
#       app  = "gitea"
#     }
#   }
  
#   spec {
#     capacity = {
#       storage = "20Gi"
#     }
    
#     access_modes = ["ReadWriteOnce"]
#     storage_class_name = kubernetes_storage_class_v1.local_fast.metadata[0].name
    
#     persistent_volume_source {
#       local {
#         path = "/mnt/local-storage/gitea"
#       }
#     }
    
#     node_affinity {
#       required {
#         node_selector_term {
#           match_expressions {
#             key      = "kubernetes.io/os"
#             operator = "In"
#             values   = ["linux"]
#           }
#           match_expressions {
#             key      = "kubernetes.io/hostname"
#             operator = "In"
#             values   = ["node-with-pv"]
#           }        
#         }
#       }
#     }
#   }
  
#   depends_on = [kubernetes_storage_class_v1.local_fast]
# }

# resource "kubernetes_persistent_volume_v1" "local_postgres" {
#   metadata {
#     name = "local-postgres"
#     labels = {
#       type = "local"
#       app  = "postgres"
#     }
#   }
  
#   spec {
#     capacity = {
#       storage = "10Gi"
#     }
    
#     access_modes = ["ReadWriteOnce"]
#     storage_class_name = kubernetes_storage_class_v1.local_fast.metadata[0].name
    
#     persistent_volume_source {
#       local {
#         path = "/mnt/local-storage/postgres"
#       }
#     }
    
#     node_affinity {
#       required {
#         node_selector_term {
#           match_expressions {
#             key      = "kubernetes.io/os"
#             operator = "In"
#             values   = ["linux"]
#           }
#           match_expressions {
#             key      = "kubernetes.io/hostname"
#             operator = "In"
#             values   = ["node-with-pv"]
#           }
#         }
#       }
#     }
#   }
  
#   depends_on = [kubernetes_storage_class_v1.local_fast]
# }

# resource "kubernetes_persistent_volume_v1" "local_general" {
#   count = var.num_general_pvs
  
#   metadata {
#     name = "local-general-${count.index}"
#     labels = {
#       type = "local"
#       app  = "general"
#     }
#   }
  
#   spec {
#     capacity = {
#       storage = "5Gi"
#     }
    
#     access_modes = ["ReadWriteOnce"]
#     storage_class_name = kubernetes_storage_class_v1.local_default.metadata[0].name
    
#     persistent_volume_source {
#       local {
#         path = "/mnt/local-storage/general/pv-${count.index}"
#       }
#     }
    
#     node_affinity {
#       required {
#         node_selector_term {
#           match_expressions {
#             key      = "kubernetes.io/os"
#             operator = "In"
#             values   = ["linux"]
#           }
#         }
#       }
#     }
#   }
  
#   depends_on = [kubernetes_storage_class_v1.local_default]
# }

# # =============================================================================
# # DAEMONSET TO PREPARE LOCAL STORAGE DIRECTORIES
# # =============================================================================

# resource "kubernetes_daemon_set_v1" "local_storage_prep" {
#   metadata {
#     name      = "local-storage-prep"
#     namespace = "kube-system"
#     labels = {
#       app = "local-storage-prep"
#     }
#   }
  
#   spec {
#     selector {
#       match_labels = {
#         app = "local-storage-prep"
#       }
#     }
    
#     template {
#       metadata {
#         labels = {
#           app = "local-storage-prep"
#         }
#       }
      
#       spec {
#         host_network = true
#         host_pid     = true
        
#         toleration {
#           operator = "Exists"
#         }
        
#         container {
#           name  = "local-storage-prep"
#           image = "busybox:1.35"
#           command = ["/bin/sh"]
#           args = [
#             "-c",
#             <<-EOT
#               set -e
#               echo "Preparing local storage directories..."
              
#               # Create all necessary directories
#               mkdir -p /host/mnt/local-storage/general
#               for i in $(seq 0 ${var.num_general_pvs - 1}); do
#                 mkdir -p /host/mnt/local-storage/general/pv-$i
#                 chmod 755 /host/mnt/local-storage/general/pv-$i
#               done
              
#               # Set proper permissions
#               chmod 755 /host/mnt/local-storage/gitea
#               chmod 755 /host/mnt/local-storage/postgres
#               chmod 755 /host/mnt/local-storage/redis
#               chmod 755 /host/mnt/local-storage/general
              
#               echo "Local storage directories prepared successfully"
              
#               # Keep the container running
#               while true; do
#                 sleep 3600
#               done
#             EOT
#           ]
          
#           security_context {
#             privileged = true
#           }
          
#           volume_mount {
#             name       = "host-root"
#             mount_path = "/host"
#           }
          
#           resources {
#             requests = {
#               cpu    = "10m"
#               memory = "16Mi"
#             }
#             limits = {
#               cpu    = "50m" 
#               memory = "32Mi"
#             }
#           }
#         }
        
#         volume {
#           name = "host-root"
#           host_path {
#             path = "/"
#           }
#         }
#       }
#     }
#   }
  
#   depends_on = [module.eks]
# }

# # =============================================================================
# # EXAMPLE PVCS FOR TESTING
# # =============================================================================

# # Example PVC for Gitea repositories
# resource "kubernetes_persistent_volume_claim_v1" "gitea_repos" {
#   count = var.create_example_pvcs ? 1 : 0
  
#   metadata {
#     name      = "gitea-repositories"
#     namespace = "default"
#     labels = {
#       app = "gitea"
#     }
#   }
  
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     storage_class_name = kubernetes_storage_class_v1.local_fast.metadata[0].name
    
#     resources {
#       requests = {
#         storage = "20Gi"
#       }
#     }
    
#     selector {
#       match_labels = {
#         app = "gitea"
#       }
#     }
#   }
  
#   depends_on = [kubernetes_persistent_volume_v1.local_gitea_repos]
# }

# # Example PVC for database
# resource "kubernetes_persistent_volume_claim_v1" "postgres_data" {
#   count = var.create_example_pvcs ? 1 : 0
  
#   metadata {
#     name      = "postgres-data"
#     namespace = "default"
#     labels = {
#       app = "postgres"
#     }
#   }
  
#   spec {
#     access_modes = ["ReadWriteOnce"]
#     storage_class_name = kubernetes_storage_class_v1.local_fast.metadata[0].name
    
#     resources {
#       requests = {
#         storage = "10Gi"
#       }
#     }
    
#     selector {
#       match_labels = {
#         app = "postgres"
#       }
#     }
#   }
  
#   depends_on = [kubernetes_persistent_volume_v1.local_postgres]
# }
