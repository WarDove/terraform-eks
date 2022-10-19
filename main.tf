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

# Declare your hosted zone and create certificates via ACM if needed
module "huseynov-net" {
  source = "./modules/hosted-zone"
  # should be apex domain
  dns_zone         = "huseynov.net"
  tls_termination  = true
  created_manually = true
  # Hosted zone will be private if VPC id entered
  # Possible values are "none" or a valid VPC id
  vpc_id = "none"

  providers = {
    aws = aws
  }
}

# Provision a gitlab instance in AWS
module "gitlab-instance" {
  source         = "./modules/gitlab-instance"
  subnet_type    = "public" # public or private
  gitlab-version = "15.4.2"
  instance_type  = "t3.micro"
  volume_size    = 10
  # list of cidr block with ssh access to instance
  ssh_cidr_blocks = []
  vpc             = module.eks-cluster.cluster-vpc
  subnet_ids      = local.cluster_subnet_ids
  # Possible values are "none", "internal" or "external"
  alb = "external"
  tls_termination  = true
  # Enter certificate arn to enable https listener and http -> https redirect
  # Possible values are "none" or a valid certificate arn
  # Cannot be set to "none" if tls_termination is true
  certificate_arn = module.huseynov-net.certificate_arn

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



# TODO: Implement Vertical and Horizontal auto scaling with eks module
# TODO: Add ec2 node groups with some logic to eks module
# TODO: AWS backups integrate with gitlab instance

