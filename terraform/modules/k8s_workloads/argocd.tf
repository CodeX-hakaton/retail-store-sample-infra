locals {
  catalog_secret_name   = "catalog-db"
  orders_db_secret_name = "orders-db"
  orders_mq_secret_name = "orders-rabbitmq"

  argocd_catalog_values = merge({
    image = {
      repository = module.container_images.result.catalog.repository
      tag        = module.container_images.result.catalog.tag
    }
    app = {
      persistence = {
        provider = "mysql"
        endpoint = "${var.dependencies.catalog_db_endpoint}:${var.dependencies.catalog_db_port}"
        secret = {
          create = false
          name   = local.catalog_secret_name
        }
      }
    }
    },
    var.opentelemetry_enabled ? {
      opentelemetry = {
        enabled         = true
        instrumentation = local.opentelemetry_instrumentation
      }
    } : {},
    !var.opentelemetry_enabled ? {
      securityGroups = {
        create           = true
        securityGroupIds = [var.security_group_ids.catalog]
      }
  } : {})

  argocd_carts_values = merge({
    image = {
      repository = module.container_images.result.cart.repository
      tag        = module.container_images.result.cart.tag
    }
    serviceAccount = {
      name = "carts"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.iam_assumable_role_carts.iam_role_arn
      }
    }
    app = {
      persistence = {
        provider = "dynamodb"
        dynamodb = {
          tableName = var.dependencies.carts_dynamodb_table_name
        }
      }
    }
    },
    var.opentelemetry_enabled ? {
      opentelemetry = {
        enabled         = true
        instrumentation = local.opentelemetry_instrumentation
      }
  } : {})

  argocd_checkout_values = merge({
    image = {
      repository = module.container_images.result.checkout.repository
      tag        = module.container_images.result.checkout.tag
    }
    app = {
      persistence = {
        provider = "redis"
        redis = {
          endpoint = "${var.dependencies.checkout_elasticache_primary_endpoint}:${var.dependencies.checkout_elasticache_port}"
        }
      }
      endpoints = {
        orders = "http://${var.environment_name}-orders.orders.svc:80"
      }
    }
    },
    var.opentelemetry_enabled ? {
      opentelemetry = {
        enabled         = true
        instrumentation = local.opentelemetry_instrumentation
      }
    } : {},
    !var.opentelemetry_enabled ? {
      securityGroups = {
        create           = true
        securityGroupIds = [var.security_group_ids.checkout]
      }
  } : {})

  argocd_orders_values = merge({
    image = {
      repository = module.container_images.result.orders.repository
      tag        = module.container_images.result.orders.tag
    }
    app = {
      persistence = {
        provider = "postgres"
        endpoint = "${var.dependencies.orders_db_endpoint}:${var.dependencies.orders_db_port}"
        database = var.dependencies.orders_db_database_name
        secret = {
          create = false
          name   = local.orders_db_secret_name
        }
      }
      messaging = {
        provider = "rabbitmq"
        rabbitmq = {
          addresses = [var.dependencies.mq_broker_endpoint]
          secret = {
            create = false
            name   = local.orders_mq_secret_name
          }
        }
      }
    }
    },
    var.opentelemetry_enabled ? {
      opentelemetry = {
        enabled         = true
        instrumentation = local.opentelemetry_instrumentation
      }
    } : {},
    !var.opentelemetry_enabled ? {
      securityGroups = {
        create           = true
        securityGroupIds = [var.security_group_ids.orders]
      }
  } : {})

  argocd_ui_values = merge({
    image = {
      repository = module.container_images.result.ui.repository
      tag        = module.container_images.result.ui.tag
    }
    app = {
      endpoints = {
        catalog  = "http://${var.environment_name}-catalog.catalog.svc:80"
        carts    = "http://${var.environment_name}-carts.carts.svc:80"
        checkout = "http://${var.environment_name}-checkout.checkout.svc:80"
        orders   = "http://${var.environment_name}-orders.orders.svc:80"
      }
    }
    },
    var.opentelemetry_enabled ? {
      opentelemetry = {
        enabled         = true
        instrumentation = local.opentelemetry_instrumentation
      }
    } : {},
    var.istio_enabled ? {
      istio = {
        enabled = true
        hosts   = ["*"]
      }
    } : {},
    !var.istio_enabled ? {
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
        }
      }
  } : {})

  argocd_applications = {
    catalog = {
      name      = "${var.environment_name}-catalog"
      namespace = kubernetes_namespace_v1.catalog.metadata[0].name
      path      = "terraform/charts/catalog"
      values    = yamlencode(local.argocd_catalog_values)
    }
    carts = {
      name      = "${var.environment_name}-carts"
      namespace = kubernetes_namespace_v1.carts.metadata[0].name
      path      = "terraform/charts/cart"
      values    = yamlencode(local.argocd_carts_values)
    }
    checkout = {
      name      = "${var.environment_name}-checkout"
      namespace = kubernetes_namespace_v1.checkout.metadata[0].name
      path      = "terraform/charts/checkout"
      values    = yamlencode(local.argocd_checkout_values)
    }
    orders = {
      name      = "${var.environment_name}-orders"
      namespace = kubernetes_namespace_v1.orders.metadata[0].name
      path      = "terraform/charts/orders"
      values    = yamlencode(local.argocd_orders_values)
    }
    ui = {
      name      = "${var.environment_name}-ui"
      namespace = kubernetes_namespace_v1.ui.metadata[0].name
      path      = "terraform/charts/ui"
      values    = yamlencode(local.argocd_ui_values)
    }
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  count = local.argocd_enabled ? 1 : 0

  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = var.argocd_namespace
  }
}

resource "helm_release" "argocd" {
  count = local.argocd_enabled ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace_v1.argocd[0].metadata[0].name
  wait       = true
}

resource "time_sleep" "argocd_controller" {
  count = local.argocd_enabled ? 1 : 0

  create_duration = "30s"

  depends_on = [
    helm_release.argocd
  ]
}

resource "kubernetes_secret_v1" "catalog_db" {
  count = local.argocd_enabled ? 1 : 0

  metadata {
    name      = local.catalog_secret_name
    namespace = kubernetes_namespace_v1.catalog.metadata[0].name
  }

  type = "Opaque"

  data = {
    RETAIL_CATALOG_PERSISTENCE_USER     = var.dependencies.catalog_db_master_username
    RETAIL_CATALOG_PERSISTENCE_PASSWORD = var.dependencies.catalog_db_master_password
  }
}

resource "kubernetes_secret_v1" "orders_db" {
  count = local.argocd_enabled ? 1 : 0

  metadata {
    name      = local.orders_db_secret_name
    namespace = kubernetes_namespace_v1.orders.metadata[0].name
  }

  type = "Opaque"

  data = {
    RETAIL_ORDERS_PERSISTENCE_USERNAME = var.dependencies.orders_db_master_username
    RETAIL_ORDERS_PERSISTENCE_PASSWORD = var.dependencies.orders_db_master_password
  }
}

resource "kubernetes_secret_v1" "orders_rabbitmq" {
  count = local.argocd_enabled ? 1 : 0

  metadata {
    name      = local.orders_mq_secret_name
    namespace = kubernetes_namespace_v1.orders.metadata[0].name
  }

  type = "Opaque"

  data = {
    RETAIL_ORDERS_MESSAGING_RABBITMQ_USERNAME = var.dependencies.mq_user
    RETAIL_ORDERS_MESSAGING_RABBITMQ_PASSWORD = var.dependencies.mq_password
  }
}

resource "kubectl_manifest" "argocd_application" {
  for_each = local.argocd_enabled ? local.argocd_applications : {}

  depends_on = [
    time_sleep.argocd_controller,
    kubernetes_secret_v1.catalog_db,
    kubernetes_secret_v1.orders_db,
    kubernetes_secret_v1.orders_rabbitmq
  ]

  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = each.value.name
      namespace = var.argocd_namespace
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.argocd_repo_url
        targetRevision = var.argocd_target_revision
        path           = each.value.path
        helm = {
          values = each.value.values
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = each.value.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  })
}

resource "null_resource" "argocd_applications_ready" {
  count = local.argocd_enabled ? 1 : 0

  triggers = {
    application_names = join(",", [for app in values(local.argocd_applications) : app.name])
    target_revision   = coalesce(var.argocd_target_revision, "")
    repo_url          = coalesce(var.argocd_repo_url, "")
  }

  depends_on = [
    kubectl_manifest.argocd_application
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(local.kubeconfig)
    }

    command = <<-EOT
      set -euo pipefail
      for app in ${join(" ", [for app in values(local.argocd_applications) : app.name])}; do
        echo "Waiting for Argo CD application: $${app}"

        if ! kubectl wait --for=jsonpath='{.status.sync.status}'=Synced "application/$${app}" -n ${var.argocd_namespace} --timeout=20m --kubeconfig <(echo "$KUBECONFIG" | base64 -d); then
          kubectl get "application/$${app}" -n ${var.argocd_namespace} -o yaml --kubeconfig <(echo "$KUBECONFIG" | base64 -d)
          exit 1
        fi

        if ! kubectl wait --for=jsonpath='{.status.health.status}'=Healthy "application/$${app}" -n ${var.argocd_namespace} --timeout=20m --kubeconfig <(echo "$KUBECONFIG" | base64 -d); then
          kubectl get "application/$${app}" -n ${var.argocd_namespace} -o yaml --kubeconfig <(echo "$KUBECONFIG" | base64 -d)
          kubectl get pods -A --kubeconfig <(echo "$KUBECONFIG" | base64 -d)
          exit 1
        fi
      done
    EOT
  }
}
