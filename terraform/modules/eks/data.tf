data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks_cluster.cluster_name

  depends_on = [
    module.eks_cluster
  ]
}
