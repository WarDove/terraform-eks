# Kubernetes manifest resources

resource "kubernetes_namespace" "gitlab-runner" {
  metadata {
    name = "gitlab-runner"
  }
}

resource "kubernetes_service_account" "gitlab-runner" {
  metadata {
    name      = "gitlab-runner"
    namespace = kubernetes_namespace.gitlab-runner.metadata[0].name
  }
}

resource "kubernetes_role" "gitlab-runner" {
  metadata {
    namespace = kubernetes_namespace.gitlab-runner.metadata[0].name
    name      = "gitlab-runner-role"
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec", "secrets", "configmaps", "pods/attach"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "gitlab-runner" {
  metadata {
    name      = "gitlab-role-rb"
    namespace = kubernetes_namespace.gitlab-runner.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.gitlab-runner.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.gitlab-runner.metadata[0].name
    namespace = kubernetes_namespace.gitlab-runner.metadata[0].name
  }
}

# Helm chart
# https://docs.gitlab.com/runner/install/kubernetes.html
resource "helm_release" "gitlab-runner" {
  name       = "gitlab-runner"
  repository = "https://charts.gitlab.io/"
  chart      = "gitlab-runner"
  version    = "0.45.0"
  namespace  = kubernetes_namespace.gitlab-runner.metadata[0].name

  values = [
    "${file("${path.cwd}/helm/gitlab-runner/values.yaml")}"
  ]

  lifecycle {
    ignore_changes = [values]
  }

  set {
    name  = "runnerRegistrationToken"
    value = var.runner_registration_token
  }

  set {
    name  = "gitlabUrl"
    value = var.gitlab_url
  }

  set {
    name  = "rbac.serviceAccountName"
    value = kubernetes_service_account.gitlab-runner.metadata[0].name
  }
}
