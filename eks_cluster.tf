locals {
  alb_public_ingress_sg_rules = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.ingress_allowed_cidrs
      description = "Restricted HTTPS access from Internet"
    }
  ]
  alb_public_egress_sg_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["eks-test"][var.env]]
      description = "Access from ALB to VPC"
    }
  ]
  alb_internal_ingress_sg_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["eks-test"][var.env]]
      description = "HTTP access from within VPC"
    }
  ]
  alb_internal_egress_sg_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["eks-test"][var.env]]
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
      cidr_blocks = [module.cidr.cidr_blocks[var.instance]["eks-test"][var.env]]
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

  cluster_name                  = var.cluster_name
  node_group_name               = "eks-test-node-group"
  eks_version                   = var.cluster_version
  vpc_id                        = module.vpc.vpc.id
  env                           = var.env
  instance                      = var.instance
  aws_region                    = var.aws_region
  subnet_ids                    = module.private_subnets.subnets[*].id
  node_group_instance_type      = lookup(var.instance_types, "eks_node_group", var.default_instance_type)
  ssh_key_name                  = data.aws_key_pair.key.key_name
  alb_public_ingress_sg_rules   = local.alb_public_ingress_sg_rules
  alb_public_egress_sg_rules    = local.alb_public_egress_sg_rules
  alb_internal_ingress_sg_rules = local.alb_internal_ingress_sg_rules
  alb_internal_egress_sg_rules  = local.alb_internal_egress_sg_rules
  cluster_ingress_sg_rules      = local.cluster_ingress_sg_rules
  cluster_egress_sg_rules       = local.cluster_egress_sg_rules
  nodegroup_ingress_sg_rules    = local.nodegroup_ingress_sg_rules
  nodegroup_egress_sg_rules     = local.nodegroup_egress_sg_rules
  # Node group scaling configuration
  scaling_config_desired_size = 2
  scaling_config_max_size     = 3
  scaling_config_min_size     = 1
  max_unavailable_nodes       = 1
}