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
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${var.account_id}:role/${aws_iam_role.aws-lbc-role.name}"
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