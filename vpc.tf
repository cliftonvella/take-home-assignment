module "vpc" {
  source = "./modules/vpc"

  instance    = var.instance
  env         = var.env
  name        = "${var.instance}-${var.env}"
  ou          = var.ou
  account     = var.account
  public      = true
  private_dns = "${var.env_alias[var.env]}.${var.project}.${var.instance}"
}

############# Load Balancer Subnets #############

module "lb_subnets_internal" {
  source       = "./modules/subnet"
  vpc          = module.vpc.vpc
  name         = "lb-int-${var.account}-${var.env}"
  az_count     = var.az_count
  cidr_newbits = 5
  cidr_offset  = 0
  extra_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/eks-test"  = "owned"
  }
}

module "lb_subnets" {
  source       = "./modules/subnet"
  vpc          = module.vpc.vpc
  name         = "lb-${var.account}-${var.env}"
  az_count     = var.az_count
  cidr_newbits = 5
  cidr_offset  = 3
  extra_tags = {
    "kubernetes.io/role/elb"         = "1"
    "kubernetes.io/cluster/eks-test" = "owned"
  }
}

resource "aws_route_table" "public_lb" {
  vpc_id = module.vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.vpc.internet_gateway.id
  }
  tags = {
    Name = "lb-public-${var.env}"
  }
  depends_on = [module.lb_subnets]
}

#Associate public LB subnets with above route table
resource "aws_route_table_association" "public_lb" {
  count          = var.az_count
  subnet_id      = module.lb_subnets.subnets[count.index].id
  route_table_id = aws_route_table.public_lb.id
}

#Create route tables for internal lb subnets
resource "aws_route_table" "internal_lb" {
  vpc_id = module.vpc.vpc.id

  tags = {
    Name = "lb-int-${var.env}"
  }
  depends_on = [module.lb_subnets_internal]
}

#Associate internal LB subnets with above route table
resource "aws_route_table_association" "internal_lb" {
  count          = var.az_count
  subnet_id      = module.lb_subnets_internal.subnets[count.index].id
  route_table_id = aws_route_table.internal_lb.id
}

############# NAT GW Subnets #############

module "nat_subnets" {
  source       = "./modules/subnet"
  vpc          = module.vpc.vpc
  name         = "nat-${var.account}-${var.env}"
  az_count     = var.az_count
  nat_required = true
  cidr_newbits = 5
  cidr_offset  = 18
}

## send non local traffic to the internet
resource "aws_route_table" "nat" {
  count  = var.az_count
  vpc_id = module.vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.vpc.internet_gateway.id
  }

  tags = {
    Name = "nat-${var.env}-${module.nat_subnets.subnets[count.index].availability_zone}"
  }
}

resource "aws_route_table_association" "nats" {
  count          = var.az_count
  route_table_id = aws_route_table.nat[count.index].id
  subnet_id      = module.nat_subnets.subnets[count.index].id
}

############# PRIVATE SUBNETS #############
module "private_subnets" {
  source       = "./modules/subnet"
  vpc          = module.vpc.vpc
  name         = "private-${var.account}-${var.env}"
  az_count     = var.az_count
  cidr_newbits = 5
  cidr_offset  = 9
}

#Create route table for private subnet
resource "aws_route_table" "private" {
  vpc_id = module.vpc.vpc.id
  count  = var.az_count

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = module.nat_subnets.nats[count.index].id
  }

  tags = {
    Name = "private-${var.env}"
  }
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = module.private_subnets.subnets[count.index].id
}