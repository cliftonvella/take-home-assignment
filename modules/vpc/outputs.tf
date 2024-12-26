output "vpc" {
  value = aws_vpc.generic
}

output "internet_gateway" {
  value = var.public ? aws_internet_gateway.this[0] : null
}

output "phz" {
  value = var.private_dns == "" ? null : aws_route53_zone.phz[0]
}
