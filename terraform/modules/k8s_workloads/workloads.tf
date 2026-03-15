# Wait for VPC Resource Controller to attach trunk ENIs to nodes
data "kubernetes_nodes" "vpc_ready_nodes" {
  depends_on = [time_sleep.workloads]

  metadata {
    labels = {
      "vpc.amazonaws.com/has-trunk-attached" = "true"
    }
  }
}

resource "kubernetes_namespace_v1" "catalog" {
  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = "catalog"

    labels = var.istio_enabled ? local.istio_labels : {}
  }
}

resource "helm_release" "catalog" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  name  = "catalog"
  chart = "${path.root}/charts/catalog"

  namespace = kubernetes_namespace_v1.catalog.metadata[0].name

  values = [
    templatefile("${path.module}/values/catalog.yaml", {
      image_repository              = module.container_images.result.catalog.repository
      image_tag                     = module.container_images.result.catalog.tag
      opentelemetry_enabled         = var.opentelemetry_enabled
      opentelemetry_instrumentation = local.opentelemetry_instrumentation
      service_monitor_enabled       = var.observability_enabled
      database_endpoint             = "${var.dependencies.catalog_db_endpoint}:${var.dependencies.catalog_db_port}"
      database_username             = var.dependencies.catalog_db_master_username
      database_password             = var.dependencies.catalog_db_master_password
      security_group_id             = var.security_group_ids.catalog
    })
  ]
}

resource "kubernetes_namespace_v1" "carts" {
  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = "carts"

    labels = var.istio_enabled ? local.istio_labels : {}
  }
}

resource "helm_release" "carts" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  name  = "carts"
  chart = "${path.root}/charts/cart"

  namespace = kubernetes_namespace_v1.carts.metadata[0].name

  values = [
    templatefile("${path.module}/values/carts.yaml", {
      image_repository              = module.container_images.result.cart.repository
      image_tag                     = module.container_images.result.cart.tag
      opentelemetry_enabled         = var.opentelemetry_enabled
      opentelemetry_instrumentation = local.opentelemetry_instrumentation
      service_monitor_enabled       = var.observability_enabled
      role_arn                      = module.iam_assumable_role_carts.iam_role_arn
      table_name                    = var.dependencies.carts_dynamodb_table_name
    })
  ]
}

resource "kubernetes_namespace_v1" "checkout" {
  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = "checkout"

    labels = var.istio_enabled ? local.istio_labels : {}
  }
}

resource "helm_release" "checkout" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  name  = "checkout"
  chart = "${path.root}/charts/checkout"

  namespace = kubernetes_namespace_v1.checkout.metadata[0].name

  values = [
    templatefile("${path.module}/values/checkout.yaml", {
      image_repository              = module.container_images.result.checkout.repository
      image_tag                     = module.container_images.result.checkout.tag
      opentelemetry_enabled         = var.opentelemetry_enabled
      opentelemetry_instrumentation = local.opentelemetry_instrumentation
      service_monitor_enabled       = var.observability_enabled
      redis_address                 = var.dependencies.checkout_elasticache_primary_endpoint
      redis_port                    = var.dependencies.checkout_elasticache_port
      security_group_id             = var.security_group_ids.checkout
    })
  ]
}

resource "kubernetes_namespace_v1" "orders" {
  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = "orders"

    labels = var.istio_enabled ? local.istio_labels : {}
  }
}

resource "helm_release" "orders" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  name  = "orders"
  chart = "${path.root}/charts/orders"

  namespace = kubernetes_namespace_v1.orders.metadata[0].name

  values = [
    templatefile("${path.module}/values/orders.yaml", {
      image_repository              = module.container_images.result.orders.repository
      image_tag                     = module.container_images.result.orders.tag
      opentelemetry_enabled         = var.opentelemetry_enabled
      opentelemetry_instrumentation = local.opentelemetry_instrumentation
      service_monitor_enabled       = var.observability_enabled
      database_endpoint_host        = var.dependencies.orders_db_endpoint
      database_endpoint_port        = var.dependencies.orders_db_port
      database_name                 = var.dependencies.orders_db_database_name
      database_username             = var.dependencies.orders_db_master_username
      database_password             = var.dependencies.orders_db_master_password
      rabbitmq_endpoint             = var.dependencies.mq_broker_endpoint
      rabbitmq_username             = var.dependencies.mq_user
      rabbitmq_password             = var.dependencies.mq_password
      security_group_id             = var.security_group_ids.orders
    })
  ]
}

resource "kubernetes_namespace_v1" "ui" {
  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = "ui"

    labels = var.istio_enabled ? local.istio_labels : {}
  }
}

resource "helm_release" "ui" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.catalog[0],
    helm_release.carts[0],
    helm_release.checkout[0],
    helm_release.orders[0]
  ]

  name  = "ui"
  chart = "${path.root}/charts/ui"

  namespace = kubernetes_namespace_v1.ui.metadata[0].name

  values = [
    templatefile("${path.module}/values/ui.yaml", {
      image_repository              = module.container_images.result.ui.repository
      image_tag                     = module.container_images.result.ui.tag
      opentelemetry_enabled         = var.opentelemetry_enabled
      opentelemetry_instrumentation = local.opentelemetry_instrumentation
      service_monitor_enabled       = var.observability_enabled
      istio_enabled                 = var.istio_enabled
      service_port                  = local.ui_load_balancer_service_port
      service_annotations           = indent(4, yamlencode(local.ui_load_balancer_service_annotations))
    })
  ]
}

resource "time_sleep" "restart_pods" {
  count = local.direct_deploy ? 1 : 0

  triggers = {
    opentelemetry_enabled = var.opentelemetry_enabled
  }

  create_duration = "30s"

  depends_on = [
    helm_release.ui[0]
  ]
}

resource "null_resource" "restart_pods" {
  count = local.direct_deploy ? 1 : 0

  depends_on = [time_sleep.restart_pods[0]]

  triggers = {
    opentelemetry_enabled = var.opentelemetry_enabled
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    command = <<-EOT
      kubectl delete pod -A -l app.kubernetes.io/owner=retail-store-sample --kubeconfig <(echo $KUBECONFIG | base64 -d)
    EOT
  }
}
