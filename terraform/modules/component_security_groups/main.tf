resource "aws_security_group" "catalog" {
  name        = "${var.environment_name}-catalog"
  description = "Security group for the catalog component."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound HTTP API traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow inbound Istio healthchecks"
    from_port   = 15020
    to_port     = 15021
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "orders" {
  name        = "${var.environment_name}-orders"
  description = "Security group for the orders component."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound HTTP API traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow inbound Istio healthchecks"
    from_port   = 15020
    to_port     = 15021
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "checkout" {
  name        = "${var.environment_name}-checkout"
  description = "Security group for the checkout component."
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow inbound HTTP API traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Allow inbound Istio healthchecks"
    from_port   = 15020
    to_port     = 15021
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
