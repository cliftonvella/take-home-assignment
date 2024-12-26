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
}

# Configure the AWS Provider & set region
provider "aws" {
  region = var.aws_region
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

module "cidr" {
  source = "./modules/cidr_blocks"
}