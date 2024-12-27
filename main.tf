terraform {
  required_version = "~> 1.10.3"
  backend "s3" {
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
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
      OU          = var.ou
      Instance    = var.instance
      Application = var.account
      Environment = var.env
      Name        = local.tag_suffix
    }
  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", "eks-test"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "eks-test"]
    }
  }
}

# Data source to get EKS cluster auth details
data "aws_eks_cluster_auth" "cluster" {
  name = "eks-test"
}

module "cidr" {
  source = "./modules/cidr_blocks"
}