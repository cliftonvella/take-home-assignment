variable "project" {
  type        = string
  description = "Project Name"
}

variable "instance" {
  type        = string
  description = "The instance of the infra e.g. gib"
}

variable "aws_account_id" {
  type        = string
  description = "The AWS Account ID"
}

variable "ou" {
  type        = string
  description = "Organisational Unit"
}

variable "account" {
  type        = string
  description = "The account within the OU"
}

variable "aws_region" {
  type = string
}

variable "az_count" {
  type    = number
  default = 1
}

variable "env" {
  type    = string
  default = "dev"
}

variable "plan_only" {
  type    = bool
  default = false
}

variable "assume_role_name" {
  type    = string
  default = "SGTerraformSpokeAccounts"
}

variable "env_alias" {
  type = map(any)
  default = {
    "prod"  = "prd",
    "stage" = "stg",
    "dev"   = "dev"
  }
}

variable "instance_types" {
  description = "A list of instance types by application"
  default     = ({})
  type        = map(string)
}

variable "default_instance_type" {
  description = "Default instance type for the environment"
  type        = string
}

variable "ami_ids" {
  type        = map(any)
  description = "AMI IDs for all instances"
}

variable "ingress_allowed_cidrs" {
  type = list(string)
  default = [
    "185.145.77.2/32"
  ]
}

variable "cloudwatch_alarms_enabled" {
  description = "Cloudwatch alarms toggle"
  type        = bool
  default     = false
}

