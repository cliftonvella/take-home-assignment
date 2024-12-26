terraform {
  required_version = "~> 1.10.3"
  backend "s3" {
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  tag_suffix  = "${var.account}-${var.ou}-${var.env}"
  assume_role = "${var.assume_role_name}${var.plan_only ? "PlanOnly" : ""}"
}

# Configure the AWS Provider & set region
provider "aws" {
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/${local.assume_role}"
  }
  default_tags {
    tags = {
      OU           = var.ou
      Instance     = var.instance
      Application  = var.account
      Environment  = var.env
      Name         = local.tag_suffix
    }
  }
}

module "data" {
  source      = "./modules/data"
  account     = var.account
  assume_role = var.assume_role_name
  aws_region  = var.aws_region
  env         = var.env
  instance    = var.instance
  ou          = var.ou
}

module "cidr" {
  source = "./modules/cidr_blocks"
}