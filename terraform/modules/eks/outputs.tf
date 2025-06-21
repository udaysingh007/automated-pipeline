output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_ca" {
  value = module.eks.cluster_certificate_authority_data
}

# Add these outputs to your existing outputs.tf file

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS node group"
  value       = module.eks.node_security_group_id
}

# # Local storage specific outputs
# output "local_default_storage_class" {
#   description = "Name of the default local storage class"
#   value       = kubernetes_storage_class_v1.local_default.metadata[0].name
# }

# output "local_fast_storage_class" {
#   description = "Name of the fast local storage class"
#   value       = kubernetes_storage_class_v1.local_fast.metadata[0].name
# }

# output "local_storage_path" {
#   description = "Base path for local storage on nodes"
#   value       = "/mnt/local-storage"
# }

# output "gitea_pvc_name" {
#   description = "Name of the Gitea PVC (if created)"
#   value       = var.create_example_pvcs ? kubernetes_persistent_volume_claim_v1.gitea_repos[0].metadata[0].name : null
# }

# output "postgres_pvc_name" {
#   description = "Name of the Postgres PVC (if created)"
#   value       = var.create_example_pvcs ? kubernetes_persistent_volume_claim_v1.postgres_data[0].metadata[0].name : null
# }

# output "available_storage_classes" {
#   description = "List of available storage classes"
#   value = [
#     kubernetes_storage_class_v1.local_default.metadata[0].name,
#     kubernetes_storage_class_v1.local_fast.metadata[0].name
#   ]
# }
