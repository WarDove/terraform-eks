# The 'aws_eks_update_kubeconfig' data source executes 'aws eks update-kubeconfig' commands
# Configures kubectl so that you can connect to an Amazon EKS cluster.
# Alternative of using aws cli: 
# aws eks --profile "${profile}" --region "${region}" update-kubeconfig --name ${cluster_name}
data "utils_aws_eks_update_kubeconfig" "bootstrap-kubeconfig" {

  depends_on = [
    aws_eks_cluster.eks-cluster
  ]

  profile      = var.profile
  cluster_name = var.cluster_name
  region       = var.region
}

resource "null_resource" "patch-coredns" {
  count = var.fargate_only_cluster ? 1 : 0

  depends_on = [
    data.utils_aws_eks_update_kubeconfig.bootstrap-kubeconfig,
    aws_eks_fargate_profile.eks-cluster-fargate
  ]

  triggers = {
    api_endpoint_up = aws_eks_cluster.eks-cluster.endpoint
  }

  provisioner "local-exec" {
    working_dir = "${path.cwd}/scripts"
    command     = "./patch_coredns_fargate.sh"
    # Use interpreter "bash" on windows if you have installed git-bash.
    # On linux no entrypoint needed or you may enter "/bin/bash" 
    interpreter = ["bash"]
  }
}
