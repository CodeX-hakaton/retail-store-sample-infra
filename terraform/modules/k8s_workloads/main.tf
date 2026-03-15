locals {
  argocd_enabled       = var.app_deployment_mode == "argocd"
  direct_deploy        = var.app_deployment_mode == "terraform"
  grafana_service_name = "observability-grafana"
  istio_labels = {
    istio-injection = "enabled"
  }
  ui_load_balancer_service_port = var.origin_tls_enabled ? 443 : 80
  ui_load_balancer_service_annotations = merge(
    {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
      "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
    },
    var.origin_tls_enabled ? {
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                  = var.origin_tls_acm_certificate_arn
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"                 = "443"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-protocol"      = "HTTP"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-port"          = "8080"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-path"          = "/actuator/health"
      "service.beta.kubernetes.io/aws-load-balancer-healthcheck-success-codes" = "200-399"
    } : {}
  )

  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "terraform"
    clusters = [{
      name = var.cluster.name
      cluster = {
        certificate-authority-data = var.cluster.certificate_authority_data
        server                     = var.cluster.endpoint
      }
    }]
    contexts = [{
      name = "terraform"
      context = {
        cluster = var.cluster.name
        user    = "terraform"
      }
    }]
    users = [{
      name = "terraform"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args = [
            "eks",
            "get-token",
            "--region",
            data.aws_region.current.name,
            "--cluster-name",
            var.cluster.name,
          ]
        }
      }
    }]
  })
}

resource "random_password" "grafana_admin" {
  count = var.observability_enabled && var.grafana_admin_password == null ? 1 : 0

  length           = 24
  special          = true
  override_special = "_%@"
}

locals {
  effective_grafana_admin_password = var.observability_enabled ? (
    var.grafana_admin_password != null ? var.grafana_admin_password : random_password.grafana_admin[0].result
  ) : null
  alert_email_enabled = var.observability_enabled && (
    var.alert_email_smarthost != null &&
    trimspace(var.alert_email_smarthost) != "" &&
    var.alert_email_username != null &&
    trimspace(var.alert_email_username) != "" &&
    var.alert_email_password != null &&
    trimspace(var.alert_email_password) != "" &&
    length(var.alert_email_recipients) > 0
  )
  alert_email_to = join(", ", var.alert_email_recipients)
  alertmanager_config_yaml = local.alert_email_enabled ? yamlencode({
    global = {
      resolve_timeout    = "5m"
      smtp_smarthost     = var.alert_email_smarthost
      smtp_from          = "warning@codex-devops.pp.ua"
      smtp_auth_username = var.alert_email_username
      smtp_auth_identity = var.alert_email_username
      smtp_auth_password = var.alert_email_password
    }
    route = {
      group_by        = ["alertname", "namespace", "service", "pod"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      receiver        = "email-warnings"
    }
    receivers = [
      {
        name = "email-warnings"
        email_configs = [
          {
            to            = local.alert_email_to
            from          = "warning@codex-devops.pp.ua"
            smarthost     = var.alert_email_smarthost
            auth_username = var.alert_email_username
            auth_identity = var.alert_email_username
            auth_password = var.alert_email_password
            require_tls   = true
          }
        ]
      }
    ]
    }) : yamlencode({
    global = {
      resolve_timeout = "5m"
    }
    route = {
      receiver = "null"
    }
    receivers = [
      {
        name = "null"
      }
    ]
  })
}

module "container_images" {
  source = "../images"

  container_image_overrides = var.container_image_overrides
}

resource "null_resource" "cluster_blocker" {
  triggers = {
    blocker = var.cluster.cluster_blocker_id
  }
}

resource "null_resource" "addons_blocker" {
  triggers = {
    blocker = var.cluster.addons_blocker_id
  }
}

resource "time_sleep" "workloads" {
  create_duration  = "30s"
  destroy_duration = "60s"

  depends_on = [
    null_resource.addons_blocker
  ]
}
