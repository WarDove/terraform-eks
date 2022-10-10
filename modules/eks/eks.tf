# ECS-CLUSTER-ROLE
data "aws_iam_policy_document" "eks-cluster-role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks-cluster-role" {
  name               = "eksClusterRole"
  assume_role_policy = data.aws_iam_policy_document.eks-cluster-role.json
}

resource "aws_iam_role_policy_attachment" "eks-cluster-role" {
  role       = aws_iam_role.eks-cluster-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS-CLUSTER
resource "aws_eks_cluster" "eks-cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks-cluster-role.arn

  enabled_cluster_log_types = ["api"]

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks-cluster.arn
    }    
    resources = ["secrets"]
  }

  vpc_config {
    subnet_ids = aws_subnet.private_subnet[*].id
    security_group_ids = aws_security_group.private[*].id
    endpoint_private_access = true
    endpoint_public_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-role
  ]
}

# LOG GROUP FOR EKS LOGGING
resource "aws_cloudwatch_log_group" "eks-cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7
}

# FARGATE-POD-EXECUTION-ROLE
data "aws_iam_policy_document" "fargate-pod-execution-role" {
  statement {
    actions = ["sts:AssumeRole"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:eks:${var.region_id}:${var.account_id}:fargateprofile/${var.cluster_name}-fargate/*"]
    }
    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate-pod-execution-role" {
  name               = "eksClusterRole"
  assume_role_policy = data.aws_iam_policy_document.fargate-pod-execution-role.json
}

resource "aws_iam_role_policy_attachment" "fargate-pod-execution-role" {
  role       = aws_iam_role.fargate-pod-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}



# # FARGATE PROFILE
# resource "aws_eks_fargate_profile" "eks-cluster-fargate" {
#   cluster_name           = aws_eks_cluster.eks-cluster.name
#   fargate_profile_name   = "example"
#   pod_execution_role_arn = aws_iam_role.example.arn
#   subnet_ids             = aws_subnet.example[*].id

#   selector {
#     namespace = "example"
#   }
# }