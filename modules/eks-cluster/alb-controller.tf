# Create Service account with respective annotations and labels for aws load balancer controller
resource "kubernetes_service_account" "aws-lbc" {
  count = var.load_balancer ? 1 : 0

  depends_on = [
    aws_eks_cluster.eks-cluster,
    aws_eks_fargate_profile.eks-cluster-fargate-kubesystem,
    aws_eks_fargate_profile.eks-cluster-fargate
  ]

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/component" = "controller",
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${var.account_id}:role/${aws_iam_role.aws-lbc-role[0].name}"
    }
  }
}

# Bootstrap aws load balancer controller with helm chart
resource "helm_release" "aws-lbc-chart" {
  count      = var.load_balancer ? 1 : 0
  name       = "aws-lbc"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.4.5"
  namespace  = "kube-system"

  depends_on = [
    kubernetes_service_account.aws-lbc
  ]

  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = false
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# AWS Load Balancer Controller Service Account Role
# Policies and roles to be granted to specific service accounts via OIDC provider
# in this case aws-load-balancer-controller service account located  in kube-system
# is getting AmazonEKSLoadBalancerControllerRole role which enables it to spin up
# application load balancers with configured rules from ingress annotations.

resource "aws_iam_policy" "aws-lbc-policy" {
  count       = var.load_balancer ? 1 : 0
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "AWS Load Balancer Controller iam policy"

  # Check if region is either us-east or us-west
  # https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html
  policy = length(regexall("us-east.*|us-west.*", "${var.region}")) > 0 ? file("${path.cwd}/iam_policies/iam_policy_us-gov.json") : file("${path.cwd}/iam_policies/iam_policy.json")
}


data "aws_iam_policy_document" "aws-lbc-role" {
  count = var.load_balancer ? 1 : 0
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
  count              = var.load_balancer ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.aws-lbc-role[0].json
  name               = "AmazonEKSLoadBalancerControllerRole"
}

resource "aws_iam_role_policy_attachment" "aws-lbc-role" {
  count      = var.load_balancer ? 1 : 0
  policy_arn = aws_iam_policy.aws-lbc-policy[0].arn
  role       = aws_iam_role.aws-lbc-role[0].name
}