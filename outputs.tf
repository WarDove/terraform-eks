output "kube-api-endpoint" {
  value = module.eks-cluster.kube-api-endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = module.eks-cluster.kubeconfig-certificate-authority-data
}