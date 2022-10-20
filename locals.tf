data "aws_caller_identity" "current" {}
data "aws_availability_zones" "current" {
  state = "available"
}

locals {
  az_names   = data.aws_availability_zones.current.names
  region     = data.aws_availability_zones.current.id
  account_id = data.aws_caller_identity.current.account_id

  # This local holds a map in which fargate profile names are the keys, and fargate
  # selectors per profile are in the value as a list of objects you can have multiple
  # selectors per profile (profile list items containing namespace and label)
  # Leave it empty or comment the value of the local if you don't need fargate profiles
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

  cluster_subnet_ids = {
    private = module.eks-cluster.cluster-public-subnet-ids
    public  = module.eks-cluster.cluster-private-subnet-ids
  }
}