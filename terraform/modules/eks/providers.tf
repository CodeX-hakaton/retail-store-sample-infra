provider "kubernetes" {
  alias    = "bootstrap"
  host     = "https://127.0.0.1"
  insecure = true
  token    = "bootstrap"
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--region",
      data.aws_region.current.name,
      "--cluster-name",
      module.eks_cluster.cluster_name,
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--region",
        data.aws_region.current.name,
        "--cluster-name",
        module.eks_cluster.cluster_name,
      ]
    }
  }
}
