# Configuration block(s) for selecting Kubernetes Pods to execute with this EKS Fargate Profile.
locals {
  selectors = [
    {
      namespace = "default",
      labels    = {}
    },
    {
      namespace = "kube-system",
      labels    = {}
    }
  ]

}

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
    subnet_ids              = aws_subnet.private_subnet[*].id
    security_group_ids      = aws_security_group.private[*].id
    endpoint_private_access = true
    endpoint_public_access  = var.public_api
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-role
  ]
}

# # log group for eks is created automatically if enabled_cluster_log_types is set on eks_cluster resource
# resource "aws_cloudwatch_log_group" "eks-cluster" {
#   name              = "/aws/eks/${var.cluster_name}/cluster"
#   retention_in_days = 7
# }

# IAM Role for EKS Addon "vpc-cni" with AWS managed policy
data "tls_certificate" "oidc_web_identity" {
  url = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider_sts" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_web_identity.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks-cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "eks-vpc-cni-role" {
  assume_role_policy = data.aws_iam_policy_document.eks-vpc-cni-role.json
  name               = "AmazonEKSVPCCNIRole"
}

resource "aws_iam_role_policy_attachment" "eks-vpc-cni-role" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks-vpc-cni-role.name
}

data "aws_iam_policy_document" "eks-vpc-cni-role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider_sts.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider_sts.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.oidc_provider_sts.arn]
      type        = "Federated"
    }
  }
}

# addons
resource "aws_eks_addon" "eks-cluster-vpc-cni" {
  cluster_name             = aws_eks_cluster.eks-cluster.name
  addon_name               = "vpc-cni"
  addon_version            = "v1.10.4-eksbuild.1"
  resolve_conflicts        = "NONE"
  service_account_role_arn = aws_iam_role.eks-vpc-cni-role.arn
}

resource "aws_eks_addon" "eks-cluster-kube-proxy" {
  cluster_name      = aws_eks_cluster.eks-cluster.name
  addon_name        = "kube-proxy"
  addon_version     = "v1.23.7-eksbuild.1"
  resolve_conflicts = "OVERWRITE"
}

# FARGATE PROFILE
resource "aws_eks_fargate_profile" "eks-cluster-fargate" {
  cluster_name           = aws_eks_cluster.eks-cluster.name
  fargate_profile_name   = "fargate-profile-${var.cluster_name}"
  pod_execution_role_arn = aws_iam_role.fargate-pod-execution-role.arn
  subnet_ids             = aws_subnet.private_subnet[*].id

  # Configuration block(s) for selecting Kubernetes Pods to execute with this EKS Fargate Profile.
  dynamic "selector" {
    for_each = local.selectors
    content {
      namespace = selector.value.namespace
      labels    = selector.value.labels
    }
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


# AWS Load Balancer Controller 
resource "aws_iam_policy" "aws-lbc-policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "AWS Load Balancer Controller iam policy"

  # Check if region is either us-east or us-west
  # https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = length(regexall("us-east.*|us-west.*", "${var.region}")) > 0 ? file("${path.cwd}/iam_policies/iam_policy_us-gov.json") : file("${path.cwd}/iam_policies/iam_policy.json")
}


data "aws_iam_policy_document" "aws-lbc-role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider_sts.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider_sts.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.oidc_provider_sts.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws-lbc-role" {
  assume_role_policy = data.aws_iam_policy_document.aws-lbc-role.json
  name               = "AmazonEKSLoadBalancerControllerRole"
}

resource "aws_iam_role_policy_attachment" "aws-lbc-role" {
  policy_arn = aws_iam_policy.aws-lbc-policy.arn
  role       = aws_iam_role.aws-lbc-role.name
}
