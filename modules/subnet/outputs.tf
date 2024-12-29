output "subnets" {
  value = aws_subnet.this
}

output "nat_gws" {
  value = var.nat_required ? aws_nat_gateway.outbound : []
}