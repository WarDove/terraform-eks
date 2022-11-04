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
  # Leave it empty or comment the value of the local if you don't need fargate profiles,
  # You can add up to five selectors to each profile.
  fargate_profiles = {

    profile-1 = [
      { namespace = "default",
      labels = {} }
    ],

    profile-2 = [
      { namespace = "gitlab-runner",
      labels = {} }
    ]
  }

  cluster_subnet_ids = {
    private = module.eks-cluster.cluster-public-subnet-ids
    public  = module.eks-cluster.cluster-private-subnet-ids
  }

  managed_node_groups = {

    group-1 = {
      subnet_type     = "private" # private or public
      desired_size    = 1
      max_size        = 2
      min_size        = 1
      max_unavailable = 1
      labels          = {}
      # https://docs.aws.amazon.com/eks/latest/APIReference/API_Nodegroup.html
      capacity_type    = "SPOT"
      ami_type         = "AL2_x86_64"
      disk_size        = 20
      instance_types   = ["t3.small", "t3.medium", "t3.large"]
      ec2_ssh_key      = "eks-admin"
      ec2_ssh_key_path = "${path.cwd}/files/id_rsa.pub" # specify path for public key location
      public_key       = file("${path.cwd}/files/id_rsa.pub")
      external_ssh     = ["185.96.126.106/32", "94.20.66.206/32"]
      # The Kubernetes taints to be applied to the nodes in the node group
      effect = ""
      key    = ""
      value  = ""
    }
  }
}