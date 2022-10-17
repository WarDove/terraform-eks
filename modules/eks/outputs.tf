output "kube_api_endpoint" {
  value = aws_eks_cluster.eks-cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks-cluster.certificate_authority[0].data
}

output "cluster-vpc" {
  value = aws_vpc.main
}

output "kubeconfig" {
  value = data.utils_aws_eks_update_kubeconfig.bootstrap-kubeconfig
}




