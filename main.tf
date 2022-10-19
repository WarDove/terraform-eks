# This local holds a map in which fargate profile names are the keys, and fargate
# selectors per profile are in the value as a list of objects you can have multiple
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

module "huseynov-net" {
  source   = "./modules/hosted-zone"
  dns_zone = "huseynov.net"
  # enter vpc_id if the hosted zone has to be private, otherwise leave empty
  vpc_id           = ""
  tls_termination  = true
  created_manually = true
  providers = {
    aws = aws
  }

}



# Provision an EKS cluster
module "eks-cluster" {
  source               = "./modules/eks-cluster"
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
    aws        = aws
    utils      = utils
    helm       = helm
    kubernetes = kubernetes
  }
}

module "gitlab-instance" {
  source          = "./modules/gitlab-instance"
  subnet_type     = "public" # public or private
  gitlab-version  = "15.4.2"
  instance_type   = "t3.micro"
  volume_size     = 10
  ssh_cidr_blocks = [] # ssh access allowed to these cidr blocks
  vpc             = module.eks-cluster.cluster-vpc
  subnet_ids      = local.cluster_subnet_ids

  providers = {
    aws = aws
  }
}

# TODO: Implement Vertical and Horizontal auto scaling with eks module
# TODO: Add ec2 node groups with some logic to eks module

