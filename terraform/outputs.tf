output "kubeconfig_context" {
  value       = module.eks.cluster_name
  description = "The context name to use with kubectl (e.g., kubectl --context=<this>)"
}

