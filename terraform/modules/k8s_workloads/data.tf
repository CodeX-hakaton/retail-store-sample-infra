data "aws_region" "current" {}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster.name

  depends_on = [
    null_resource.cluster_blocker
  ]
}

data "kubernetes_service" "ui_service_direct" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [helm_release.ui[0]]

  metadata {
    name      = "ui"
    namespace = "ui"
  }
}

data "kubernetes_service" "ui_service_argocd" {
  count = local.argocd_enabled ? 1 : 0

  depends_on = [null_resource.argocd_applications_ready[0]]

  metadata {
    name      = "${var.environment_name}-ui"
    namespace = "ui"
  }
}

data "kubernetes_service" "istio_ingress_service_direct" {
  count = local.direct_deploy && var.istio_enabled ? 1 : 0

  depends_on = [helm_release.ui[0]]

  metadata {
    name      = "istio-ingress"
    namespace = "istio-ingress"
  }
}

data "kubernetes_service" "istio_ingress_service_argocd" {
  count = local.argocd_enabled && var.istio_enabled ? 1 : 0

  depends_on = [null_resource.argocd_applications_ready[0]]

  metadata {
    name      = "istio-ingress"
    namespace = "istio-ingress"
  }
}

data "kubernetes_ingress_v1" "argocd_server" {
  count = local.argocd_enabled && var.argocd_public_enabled ? 1 : 0

  depends_on = [
    helm_release.argocd[0]
  ]

  metadata {
    name      = "argocd-server"
    namespace = var.argocd_namespace
  }
}
