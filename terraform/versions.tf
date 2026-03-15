terraform {
  required_version = ">= 1.0.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "backup_replica"
  region = coalesce(var.aws_backup_destination_region, var.region)
}

provider "cloudflare" {}

provider "kubernetes" {
  host                   = module.retail_app_eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.retail_app_eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--region",
      var.region,
      "--cluster-name",
      module.retail_app_eks.eks_cluster_id,
    ]
  }
}

provider "kubectl" {
  apply_retry_count = 10
  load_config_file  = true
  config_path       = pathexpand("~/.kube/config")
  config_context    = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${module.retail_app_eks.eks_cluster_id}"
}

provider "helm" {
  kubernetes {
    host                   = module.retail_app_eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.retail_app_eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--region",
        var.region,
        "--cluster-name",
        module.retail_app_eks.eks_cluster_id,
      ]
    }
  }
}
