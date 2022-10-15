# Providers
provider "aws" {

  profile = var.profile
  region  = var.region

}

# Provision an EKS cluster
module "eks-cluster" {

  source       = "./modules/eks"
  cluster_name = var.cluster_name
  public_api   = true
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 2
  az_names     = local.az_names
  region       = local.region
  account_id   = local.account_id

  providers = {
    aws = aws
  }

}

data "utils_aws_eks_update_kubeconfig" "bootstrap-kubeconfig" {

  depends_on = [
    module.eks-cluster.kube_api_endpoint
  ]

  profile      = var.profile
  cluster_name = var.cluster_name
  region       = local.region

}

# Bootstrap coredns changes to comply with fargate and deploy alb resources
# kubectl, aws cli, helm "v3.8.2" and jq must be installed on terraform machine
# https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/#install-kubectl-binary-with-curl-on-windows
resource "null_resource" "init-kubectl" {

  depends_on = [
    data.utils_aws_eks_update_kubeconfig.bootstrap-kubeconfig
  ]

  triggers = {
    #api_endpoint_up = module.eks-cluster.kube_api_endpoint
    api_endpoint_up = "test1"
  }

  provisioner "local-exec" {
    working_dir = "${path.cwd}/scripts"
    command     = "./aws_kubernetes_provisioner.sh"

    # Use interpreter "bash" on windows if you have installed git-bash.
    # On linux no entrypoint needed or you may enter "/bin/bash" 
    interpreter = ["bash"]
    environment = {
      REGION       = local.region
      ACCOUNT_ID   = local.account_id
      CLUSTER_NAME = var.cluster_name
      VPC_ID       = module.eks-cluster.cluster-vpc.id
    }
  }
}
