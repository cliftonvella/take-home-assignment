variable "name" {
  type    = string
  default = "Name of the subnet - will be used as a name prefix"
}

variable "vpc" {
}

variable "az_count" {
  type    = number
  default = 1
}

variable "nat_required" {
  type    = bool
  default = false
}

variable "cidr_newbits" {
  type = number
}

variable "cidr_offset" {
  type = number
}

variable "firewall_type" {
  type        = string
  default     = "none"
  description = "Types are none, ingress and egress.  For ingress, this will add routes in between the internet gateway and the given protected subnets"
}

variable "internet_gateway" {
  default     = ""
  description = "Which internet gateway to link the firewall to"
}

variable "protected_subnets" {
  default     = []
  description = "Which protected subnet to link the firewall to"
}

variable "route_table_association" {
  default = {}
}
variable "extra_tags" {
  description = "Extra tags to apply to the subnet"
  type = map(any)
  default = {}
}