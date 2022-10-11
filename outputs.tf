output "kube_api_endpoint" {
  value = module.eks-cluster.kube_api_endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = module.eks-cluster.kubeconfig-certificate-authority-data
}