variable "instance" {
  type = string
}

variable "name" {
  type = string
}

variable "env" {
  type = string
}

variable "account" {
  type = string
}

variable "ou" {
  type = string
}

variable "public" {
  type    = bool
  default = false
}

variable "private_dns" {
  description = "Name of private hosted zone e.g. gameop.net"
  type        = string
  default     = ""
}

variable "enable_dns_hostnames"{
  description = "Set the enable_dns_hostnames attribute"
  type        = bool
  default     = false
}