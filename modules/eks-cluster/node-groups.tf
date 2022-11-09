# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group
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
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks-node-role-ecr" {
  role       = aws_iam_role.eks-node-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# To enable nodes to push into ECR - as well as the pods that inherit this role.
resource "aws_iam_role_policy_attachment" "eks-node-role-ecr-write" {
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

resource "aws_security_group" "source_security_group" {
  name        = "mng_source_security_group"
  description = "Security group for allowing ssh access into managed node groups"
  vpc_id      = aws_vpc.main.id

  # Adding external ssh access if at least one cidr block is set in external_ssh
  dynamic "ingress" {
    for_each = length(var.external_ssh) > 0 ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.external_ssh
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mng_source_security_group"
  }
}

resource "aws_key_pair" "ec2_ssh_key" {
  count      = var.managed_node_groups != {} ? 1 : 0
  key_name   = "mng_ssh_key"
  public_key = var.public_key
}

resource "aws_eks_node_group" "eks-node-group" {

  for_each        = var.managed_node_groups
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks-node-role.arn
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
  capacity_type        = each.value.capacity_type
  ami_type             = each.value.ami_type
  disk_size            = each.value.disk_size
  instance_types       = each.value.instance_types
  labels               = each.value.labels

  remote_access {
    ec2_ssh_key               = aws_key_pair.ec2_ssh_key[0].key_name
    source_security_group_ids = [aws_security_group.source_security_group.id]
  }
  # The Kubernetes taints to be applied to the nodes in the node group.
  dynamic "taint" {
    for_each = each.value.taint != {} ? [1] : []
    content {
      effect = each.value.taint.effect
      key    = each.value.taint.key
      value  = each.value.taint.value
    }
  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks-node-role-main,
    aws_iam_role_policy_attachment.eks-node-role-ecr
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}