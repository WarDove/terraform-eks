# This local holds a map in which fargate profile names are the keys, and fargate
# selectors per profile are in the value as a list of objecs you can have multiple 
# selectors per profile (profile list items containing namespace and label)
# Leave it empty or comment the value of the local if you don't need fargate profiles
locals {
  fargate_profiles = {

    profile-1 = [
      { namespace = "default",
      labels = {} }
    ],

    profile-2 = [
      { namespace = "my-namespace",
      labels = {} }
    ]
  }
}

# Provision an EKS cluster
module "eks-cluster" {
  source               = "./modules/eks"
  cluster_name         = var.cluster_name
  public_api           = true
  load_balancer        = true
  fargate_only_cluster = true
  fargate_profiles     = local.fargate_profiles
  vpc_cidr             = "10.0.0.0/16"
  az_count             = 2
  az_names             = local.az_names
  region               = local.region
  account_id           = local.account_id
  profile              = var.profile

  providers = {
    aws   = aws
    utils = utils
    helm  = helm
  }
}
