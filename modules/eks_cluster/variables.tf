variable "env" {
  type = string
}

variable "instance" {
  type = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "Deployment region"
  type        = string
}

variable "node_group_name" {
  description = "The name of the EKS node group"
  type        = string
}

variable "subnet_ids" {
  description = "The subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "vpc_id" {
  description = "Value of the VPC ID"
  type        = string
}

variable "ssh_key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "eks_version" {
  description = "The EKS version"
  type        = string
}

variable "alb_public_ingress_sg_rules" {
  description = "Public ALB security group ingress rules"
  type = list(object({
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    from_port       = number
    to_port         = number
    protocol        = string
    description     = string
  }))
  default = []
}

variable "alb_public_egress_sg_rules" {
  description = "Public ALB security group egress rules"
  type = list(object({
    cidr_blocks = list(string)
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = []
}

variable "alb_internal_ingress_sg_rules" {
  description = "Internal ALB security group ingress rules"
  type = list(object({
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    from_port       = number
    to_port         = number
    protocol        = string
    description     = string
  }))
  default = []
}

variable "alb_internal_egress_sg_rules" {
  description = "Internal ALB security group egress rules"
  type = list(object({
    cidr_blocks = list(string)
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = []
}

variable "cluster_ingress_sg_rules" {
  description = "EKS cluster security group ingress rules"
  type = list(object({
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    from_port       = number
    to_port         = number
    protocol        = string
    description     = string
  }))
  default = []
}

variable "cluster_egress_sg_rules" {
  description = "EKS cluster security group egress rules"
  type = list(object({
    cidr_blocks = list(string)
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = []
}

variable "nodegroup_ingress_sg_rules" {
  description = "EKS nodes security group ingress rules"
  type = list(object({
    cidr_blocks     = optional(list(string))
    security_groups = optional(list(string))
    from_port       = number
    to_port         = number
    protocol        = string
    description     = string
  }))
  default = []
}

variable "nodegroup_egress_sg_rules" {
  description = "EKS nodes security group egress rules"
  type = list(object({
    cidr_blocks = list(string)
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = []
}

variable "scaling_config_desired_size" {
  description = "The desired number of worker nodes"
  type        = number
}

variable "scaling_config_max_size" {
  description = "The maximum number of worker nodes"
  type        = number
}

variable "scaling_config_min_size" {
  description = "The minimum number of worker nodes"
  type        = number
}
variable "max_unavailable_nodes" {
  description = "The maximum number of unavailable nodes"
  type        = number
}
variable "node_group_instance_type" {
  description = "The instance type for the EKS node group"
  type        = string
}