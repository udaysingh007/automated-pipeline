output "argocd_ingress_host" {
  value = "argocd.example.com"
}

# output "cluster_endpoint" {
#   value = aws_eks_cluster.eks.endpoint
# }

# output "kubeconfig" {
#   value = <<EOT
# apiVersion: v1
# clusters:
# - cluster:
#     server: ${aws_eks_cluster.eks.endpoint}
#     certificate-authority-data: ${aws_eks_cluster.eks.certificate_authority[0].data}
#   name: ${aws_eks_cluster.eks.name}
# contexts:
# - context:
#     cluster: ${aws_eks_cluster.eks.name}
#     user: aws
#   name: ${aws_eks_cluster.eks.name}
# current-context: ${aws_eks_cluster.eks.name}
# kind: Config
# preferences: {}
# users:
# - name: aws
#   user:
#     exec:
#       apiVersion: client.authentication.k8s.io/v1beta1
#       command: aws
#       args:
#         - "eks"
#         - "get-token"
#         - "--cluster-name"
#         - "${aws_eks_cluster.eks.name}"
#         - "--region"
#         - "${var.region}"
# EOT
# }
