locals {
  argocd_enabled = var.app_deployment_mode == "argocd"
  direct_deploy  = var.app_deployment_mode == "terraform"
  istio_labels = {
    istio-injection = "enabled"
  }

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
        token = data.aws_eks_cluster_auth.this.token
      }
    }]
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
