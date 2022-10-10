data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "current" {
  state = "available"
}

module "eks-cluster" {
  source   = "./modules/eks"
  cluster_name = "eks-cluster"
  vpc_cidr = "10.0.0.0/16"
  az_count = 2
  az_names = data.aws_availability_zones.current.names
  region_id = data.aws_availability_zones.current.id
  account_id = data.aws_caller_identity.current.account_id
  providers = {
    aws = aws
  }
}

