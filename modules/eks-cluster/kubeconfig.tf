# The 'aws_eks_update_kubeconfig' data source executes 'aws eks update-kubeconfig' commands
# Configures kubectl so that you can connect to an Amazon EKS cluster from local kubectl.
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


# if this is a fargate-only cluster we will need to remove specific annotation
# ("eks.amazonaws.com/compute-type": "ec2") from coredns deployment  to enable
# its deployment on fargate

# In AWS EKS, clusters come "pre-configured" with several things running in the kube-system namespace.
# We need to patch those pre-configured things, while retaining any "upstream" changes which happen to be made.
# (for example: set HTTP_PROXY variables) kubectl provides the patch keyword to handle this use-case.
# The kubernetes provider for terraform should do the same.
# worked it around with a provisioner and bash script that patches the deployment

resource "null_resource" "patch-coredns" {
  depends_on = [
    # depends on fargate profile for kube-system namespace
    # if it is an only fargate cluster
    # kubeconfig has to be set up for kubectl patch commands
    aws_eks_fargate_profile.eks-cluster-fargate-kubesystem,
    data.utils_aws_eks_update_kubeconfig.bootstrap-kubeconfig
    ]

  triggers = {
    api_endpoint_up = aws_eks_cluster.eks-cluster.endpoint
    fargate_only    = var.fargate_only_cluster
  }

  provisioner "local-exec" {
    working_dir = "${path.cwd}/scripts"
    command     = "./patch_coredns_fargate.sh"
    # Use interpreter "bash" on windows if you have installed git-bash.
    # On linux no entrypoint needed or you may enter "/bin/bash"
    interpreter = ["bash"]
    environment = {
      FARGATE_ONLY = var.fargate_only_cluster
    }
  }
}