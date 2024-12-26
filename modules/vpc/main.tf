locals {
  tag_suffix = "${var.account}-${var.ou}"
  vpc_name   = "${var.name}-${local.tag_suffix}"
}


module "cidr_blocks" {
  source = "../cidr_blocks"
}


resource "aws_vpc" "generic" {
  cidr_block = lookup(module.cidr_blocks.cidr_blocks[var.instance][var.account], var.env)

  enable_dns_hostnames = var.private_dns == "" ? var.enable_dns_hostnames : true
  enable_dns_support   = true

  tags = {
    Name = local.vpc_name
  }
}

# Add internet gateway if public
resource "aws_internet_gateway" "this" {
  count  = var.public ? 1 : 0
  vpc_id = aws_vpc.generic.id
}

# associating a route53 zone with a VPC makes it private
resource "aws_route53_zone" "phz" {
  count   = var.private_dns == "" ? 0 : 1
  name    = var.private_dns
  comment = "${var.private_dns}-${var.env}-${var.instance}"

  vpc {
    vpc_id = aws_vpc.generic.id
  }
}