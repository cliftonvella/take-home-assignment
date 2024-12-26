locals {
  alb_ingress_sg_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.ingress_allowed_cidrs
      description = "Restricted HTTPS access from Internet"
    }
  ]
  alb_egress_sg_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["sandbox"][var.env]]
      description = "Access from ALB to VPC"
    }
  ]
  cluster_ingress_sg_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = module.private_subnets.subnets[*].cidr_block
      description = "Communication between EKS nodes and cluster API server"
    }
  ]
  cluster_egress_sg_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["sandbox"][var.env]]
      description = "Access from cluster to VPC"
    }
  ]
  nodegroup_ingress_sg_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = module.lb_subnets.subnets[*].cidr_block
      description = "Access from ALB subnets to EKS nodes"
    },
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = module.private_subnets.subnets[*].cidr_block
      description = "Communication between EKS nodes and from Control Plane"
    }
  ]
  nodegroup_egress_sg_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Internet Access via NAT GW - HTTP"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "Internet Access via NAT GW - HTTPS"
    }
  ]
}

module "eks_cluster" {
  source = "./modules/eks_cluster"

  cluster_name         = "take_home_assignment"
  node_group_name      = "cluster_nodes"
  eks_version          = "1.31"
  vpc_id               = module.vpc.vpc.id
  env                  = var.env
  instance             = var.instance
  aws_region           = var.aws_region
  subnet_ids           = module.private_subnets.subnets[*].id
  ssh_key_name         = data.aws_key_pair.key.key_name
  alb_ingress_sg_rules = local.alb_ingress_sg_rules
  alb_egress_sg_rules  = local.alb_egress_sg_rules
  cluster_ingress_sg_rules = local.cluster_ingress_sg_rules
  cluster_egress_sg_rules = local.cluster_egress_sg_rules
  nodegroup_ingress_sg_rules = local.nodegroup_ingress_sg_rules
  nodegroup_egress_sg_rules = local.nodegroup_egress_sg_rules
  scaling_config_desired_size = 2
  scaling_config_max_size = 3
  scaling_config_min_size = 1
  max_unavailable_nodes = 1
}