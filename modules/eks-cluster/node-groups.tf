data "aws_iam_policy_document" "eks-node-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks-node-role" {
  name               = "AmazonEKSNodeRole"
  assume_role_policy = data.aws_iam_policy_document.eks-node-role.json
}

resource "aws_iam_role_policy_attachment" "eks-node-role-main" {
  role       = aws_iam_role.eks-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"  #AmazonEC2ContainerRegistryPowerUser
}

resource "aws_iam_role_policy_attachment" "eks-node-role-ecr" {
  role       = aws_iam_role.eks-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

/*
  The Amazon EC2 node groups must have a different IAM role than the Fargate profile. For more information, see Amazon
  EKS pod execution IAM role.
   https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html
   https://docs.aws.amazon.com/eks/latest/userguide/pod-execution-role.html
  AmazonEKS_CNI_Policy policy is attached to an IAM role that is mapped to the aws-node Kubernetes service account
  instead. For more information, see Configuring the Amazon VPC CNI plugin for Kubernetes  to use IAM roles for service
  accounts.
   https://docs.aws.amazon.com/eks/latest/userguide/cni-iam-role.html
*/

resource "aws_eks_node_group" "eks-node-group" {
  for_each = {}
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = each.value.group_name
  node_role_arn   = aws_iam_role.eks-node-role
  subnet_ids      = each.value.subnet_type == "private" ? aws_subnet.private_subnet[*].id : aws_subnet.public_subnet[*].id

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable = each.value.max_unavailable
  }
  force_update_version = true
  capacity_type = each.value.capacity_type
  ami_type = ""
  disk_size = ""
  instance_types = []
  labels = {}

  remote_access {
    ec2_ssh_key = ""
    source_security_group_ids = ""
  }

  taint {
    effect = ""
    key    = ""
    value = ""
  }

# TODO: complete locals and variables part for managed node groups
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-node-role-main,
    aws_iam_role_policy_attachment.eks-node-role-ecr
  ]
}