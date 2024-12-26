output "subnets" {
  value = aws_subnet.this
}

output "nats" {
  value = var.nat_required ? aws_nat_gateway.outbound : []
}