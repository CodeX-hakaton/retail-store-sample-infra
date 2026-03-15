locals {
  retail_app_origin_hostname = var.istio_enabled ? try(
    data.kubernetes_service.istio_ingress_service_direct[0].status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service.istio_ingress_service_argocd[0].status[0].load_balancer[0].ingress[0].hostname,
    null
    ) : try(
    data.kubernetes_service.ui_service_direct[0].status[0].load_balancer[0].ingress[0].hostname,
    data.kubernetes_service.ui_service_argocd[0].status[0].load_balancer[0].ingress[0].hostname,
    null
  )
  argocd_origin_hostname = try(
    data.kubernetes_ingress_v1.argocd_server[0].status[0].load_balancer[0].ingress[0].hostname,
    null
  )
  grafana_origin_hostname = try(
    data.kubernetes_ingress_v1.grafana[0].status[0].load_balancer[0].ingress[0].hostname,
    null
  )
}

output "retail_app_origin_hostname" {
  description = "Origin hostname exposed by the Kubernetes edge service."
  value       = local.retail_app_origin_hostname
}

output "retail_app_url" {
  description = "URL to access the retail store application."
  value = local.retail_app_origin_hostname != null ? format(
    "%s://%s",
    var.origin_tls_enabled ? "https" : "http",
    local.retail_app_origin_hostname
  ) : "LoadBalancer provisioning - run: kubectl get svc -n ${var.istio_enabled ? "istio-ingress" : "ui"} ${var.istio_enabled ? "istio-ingress" : "ui"}"
}

output "argocd_origin_hostname" {
  description = "Origin hostname exposed by the Argo CD public ingress."
  value       = local.argocd_origin_hostname
}

output "argocd_url" {
  description = "URL to access Argo CD through its public ingress."
  value       = local.argocd_origin_hostname != null ? "https://${local.argocd_origin_hostname}" : "Ingress provisioning - run: kubectl get ingress -n ${var.argocd_namespace} argocd-server"
}

output "grafana_origin_hostname" {
  description = "Origin hostname exposed by the Grafana ingress."
  value       = local.grafana_origin_hostname
}

output "grafana_url" {
  description = "URL to access Grafana through its public ingress."
  value       = local.grafana_origin_hostname != null ? "https://${local.grafana_origin_hostname}" : "Ingress provisioning - run: kubectl get ingress -n ${var.observability_namespace} ${local.grafana_service_name}"
}

output "grafana_admin_password" {
  description = "Grafana admin password."
  value       = var.observability_enabled ? local.effective_grafana_admin_password : null
  sensitive   = true
}
