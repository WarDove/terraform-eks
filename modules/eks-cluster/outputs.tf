output "kube-api-endpoint" {
  value = aws_eks_cluster.eks-cluster.endpoint
}

output "kube-api-token" {
  value = data.aws_eks_cluster_auth.eks-cluster.token
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks-cluster.certificate_authority[0].data
}

output "cluster-vpc" {
  value = aws_vpc.main
}

output "cluster-public-subnet-ids" {
  value = aws_subnet.private_subnet[*].id
}

output "cluster-private-subnet-ids" {
  value = aws_subnet.public_subnet[*].id
}




