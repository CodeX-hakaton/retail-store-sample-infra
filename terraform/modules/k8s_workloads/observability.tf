resource "kubernetes_namespace_v1" "observability" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    data.kubernetes_nodes.vpc_ready_nodes
  ]

  metadata {
    name = var.observability_namespace
  }
}

resource "helm_release" "loki" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.observability
  ]

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = kubernetes_namespace_v1.observability[0].metadata[0].name
  wait       = true

  values = [
    yamlencode({
      fullnameOverride = "loki"
      grafana = {
        enabled = false
      }
      prometheus = {
        enabled = false
      }
      filebeat = {
        enabled = false
      }
      logstash = {
        enabled = false
      }
      fluent-bit = {
        enabled = false
      }
      promtail = {
        enabled = true
      }
      loki = {
        isDefault = false
        persistence = {
          enabled = false
        }
      }
    })
  ]
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.observability,
    helm_release.loki
  ]

  name       = "observability"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.observability[0].metadata[0].name
  wait       = true

  values = [
    yamlencode({
      grafana = merge({
        adminPassword = local.effective_grafana_admin_password
        service = {
          type = "ClusterIP"
        }
        sidecar = {
          dashboards = {
            enabled          = true
            label            = "grafana_dashboard"
            labelValue       = "1"
            folderAnnotation = "grafana_folder"
            searchNamespace  = var.observability_namespace
          }
        }
        persistence = {
          enabled = false
        }
        additionalDataSources = [
          {
            name      = "Loki"
            type      = "loki"
            uid       = "loki"
            url       = "http://loki:3100"
            access    = "proxy"
            isDefault = false
          }
        ]
        },
        var.grafana_public_enabled ? {
          ingress = {
            enabled          = true
            ingressClassName = "alb"
            annotations = {
              "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
              "alb.ingress.kubernetes.io/target-type"      = "ip"
              "alb.ingress.kubernetes.io/backend-protocol" = "HTTP"
              "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTPS\":443}]"
              "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
              "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
              "alb.ingress.kubernetes.io/certificate-arn"  = var.grafana_origin_tls_acm_certificate_arn
            }
            hosts = [var.grafana_public_hostname]
            path  = "/"
          }
        } : {},
        var.grafana_public_enabled ? {
          "grafana.ini" = {
            server = {
              domain   = var.grafana_public_hostname
              root_url = "https://${var.grafana_public_hostname}"
            }
          }
      } : {})
      prometheus = {
        prometheusSpec = {
          retention                               = "7d"
          serviceMonitorSelector                  = {}
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorNamespaceSelector         = {}
          podMonitorSelector                      = {}
          podMonitorSelectorNilUsesHelmValues     = false
          podMonitorNamespaceSelector             = {}
        }
      }
      alertmanager = {
        config           = yamldecode(local.alertmanager_config_yaml)
        alertmanagerSpec = {}
      }
    })
  ]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_sla_uptime" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  metadata {
    name      = "grafana-dashboard-retail-sla-uptime"
    namespace = var.observability_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Retail Store"
    }
  }

  data = {
    "retail-sla-uptime.json" = file("${path.module}/dashboards/retail-sla-uptime.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_dashboard_scaling" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  metadata {
    name      = "grafana-dashboard-retail-scaling"
    namespace = var.observability_namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Retail Store"
    }
  }

  data = {
    "retail-scaling-capacity.json" = file("${path.module}/dashboards/retail-scaling-capacity.json")
  }
}

resource "kubectl_manifest" "observability_alerts" {
  count = var.observability_enabled ? 1 : 0

  depends_on = [
    helm_release.kube_prometheus_stack
  ]

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "retail-observability-alerts"
      namespace = var.observability_namespace
      labels = {
        release = helm_release.kube_prometheus_stack[0].name
      }
    }
    spec = {
      groups = [
        {
          name = "retail-store-capacity"
          rules = [
            {
              alert = "RetailHighCpuUtilization"
              expr  = "100 * sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{namespace=~\"ui|catalog|carts|checkout|orders\", container!=\"\", container!=\"POD\"}[5m])) / clamp_min(sum by (namespace, pod) (kube_pod_container_resource_limits{namespace=~\"ui|catalog|carts|checkout|orders\", resource=\"cpu\", unit=\"core\"}), 0.001) > 80"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "CPU utilization is above 80% of pod limit"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has used more than 80% of its CPU limit for 10 minutes."
              }
            },
            {
              alert = "RetailHighMemoryUtilization"
              expr  = "100 * sum by (namespace, pod) (container_memory_working_set_bytes{namespace=~\"ui|catalog|carts|checkout|orders\", container!=\"\", container!=\"POD\"}) / clamp_min(sum by (namespace, pod) (kube_pod_container_resource_limits{namespace=~\"ui|catalog|carts|checkout|orders\", resource=\"memory\", unit=\"byte\"}), 1) > 80"
              for   = "10m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Memory utilization is above 80% of pod limit"
                description = "Pod {{ $labels.namespace }}/{{ $labels.pod }} has used more than 80% of its memory limit for 10 minutes."
              }
            },
            {
              alert = "RetailHighP95Latency"
              expr  = "histogram_quantile(0.95, sum by (namespace, service, le) (rate(http_server_requests_seconds_bucket{namespace=~\"ui|catalog|carts|checkout|orders\"}[5m]))) > 1"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "P95 request latency is above 1 second"
                description = "Service {{ $labels.namespace }}/{{ $labels.service }} has had p95 latency above 1 second for 5 minutes."
              }
            }
          ]
        }
      ]
    }
  })
}
