locals {
  repository_names = {
    catalog  = "${var.environment_name}-catalog"
    cart     = "${var.environment_name}-cart"
    checkout = "${var.environment_name}-checkout"
    orders   = "${var.environment_name}-orders"
    ui       = "${var.environment_name}-ui"
  }
}

resource "aws_ecr_repository" "service" {
  for_each = local.repository_names

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name      = each.value
    component = each.key
  })
}
