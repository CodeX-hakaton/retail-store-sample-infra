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
}

output "retail_app_origin_hostname" {
  description = "Origin hostname exposed by the Kubernetes edge service."
  value       = local.retail_app_origin_hostname
}

output "retail_app_url" {
  description = "URL to access the retail store application."
  value       = local.retail_app_origin_hostname != null ? "http://${local.retail_app_origin_hostname}" : "LoadBalancer provisioning - run: kubectl get svc -n ui ui"
}
