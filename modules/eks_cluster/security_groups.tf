resource "aws_security_group" "alb" {
  name        = "alb-${var.cluster_name}-${var.env}-${var.instance}"
  description = "For ${var.cluster_name} load balancer"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.alb_ingress_sg_rules
    iterator = rule
    content {
      from_port       = rule.value.from_port
      to_port         = rule.value.to_port
      protocol        = rule.value.protocol
      cidr_blocks     = rule.value.cidr_blocks
      security_groups = rule.value.security_groups
      description     = rule.value.description
    }
  }

  dynamic "egress" {
    for_each = var.alb_egress_sg_rules
    iterator = rule
    content {
      from_port   = rule.value.from_port
      to_port     = rule.value.to_port
      protocol    = rule.value.protocol
      cidr_blocks = rule.value.cidr_blocks
      description = rule.value.description
    }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "node_group" {
  name        = "${var.node_group_name}-${var.env}-${var.instance}"
  description = "For ${var.cluster_name} EKS node group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.nodegroup_ingress_sg_rules
    iterator = rule
    content {
      from_port       = rule.value.from_port
      to_port         = rule.value.to_port
      protocol        = rule.value.protocol
      cidr_blocks     = rule.value.cidr_blocks
      security_groups = rule.value.security_groups
      description     = rule.value.description
    }
  }

  dynamic "egress" {
    for_each = var.nodegroup_egress_sg_rules
    iterator = rule
    content {
      from_port   = rule.value.from_port
      to_port     = rule.value.to_port
      protocol    = rule.value.protocol
      cidr_blocks = rule.value.cidr_blocks
      description = rule.value.description
    }
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-${var.env}-${var.instance}"
  description = "For ${var.cluster_name} EKS cluster"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.cluster_ingress_sg_rules
    iterator = rule
    content {
      from_port       = rule.value.from_port
      to_port         = rule.value.to_port
      protocol        = rule.value.protocol
      cidr_blocks     = rule.value.cidr_blocks
      security_groups = rule.value.security_groups
      description     = rule.value.description
    }
  }

  dynamic "egress" {
    for_each = var.cluster_egress_sg_rules
    iterator = rule
    content {
      from_port   = rule.value.from_port
      to_port     = rule.value.to_port
      protocol    = rule.value.protocol
      cidr_blocks = rule.value.cidr_blocks
      description = rule.value.description
    }
  }

  lifecycle { create_before_destroy = true }
}