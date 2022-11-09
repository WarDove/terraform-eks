# FARGATE PROFILE
resource "aws_eks_fargate_profile" "eks-cluster-fargate" {
  for_each               = var.fargate_profiles
  cluster_name           = aws_eks_cluster.eks-cluster.name
  fargate_profile_name   = "fargate-profile-${each.key}"
  pod_execution_role_arn = aws_iam_role.fargate-pod-execution-role.arn
  subnet_ids             = aws_subnet.private_subnet[*].id
  # Configuration block(s) for selecting Kubernetes Pods to execute with this
  # EKS Fargate Profile. for this locals must be set in root module.
  dynamic "selector" {
    for_each = each.value
    content {
      namespace = selector.value.namespace
      labels    = selector.value.labels
    }
  }
}

# if this is a fargate-only cluster creating a fargate profile for kube-system namespace
# If this cluster is fargate only (no ec2 node groups) then kube-system workloads not managed
# by aws (i.e coredns add-on pods) have to be provisioned by a fargate group
resource "aws_eks_fargate_profile" "eks-cluster-fargate-kubesystem" {
  count                  = local.fargate_only_cluster ? 1 : 0
  cluster_name           = aws_eks_cluster.eks-cluster.name
  fargate_profile_name   = "fargate-profile-kubesystem"
  pod_execution_role_arn = aws_iam_role.fargate-pod-execution-role.arn
  subnet_ids             = aws_subnet.private_subnet[*].id

  selector {
    namespace = "kube-system"
    labels    = {}
  }
}




# fargate pod execution role
data "aws_iam_policy_document" "fargate-pod-execution-role" {
  statement {
    actions = ["sts:AssumeRole"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:eks:${var.region}:${var.account_id}:fargateprofile/${var.cluster_name}/*"]
    }

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate-pod-execution-role" {
  name               = "AmazonEKSFargatePodExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.fargate-pod-execution-role.json
}

resource "aws_iam_role_policy_attachment" "fargate-pod-execution-role" {
  role       = aws_iam_role.fargate-pod-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}