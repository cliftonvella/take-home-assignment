output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "public_alb_sg_id" {
  description = "Security group ID for public ALB"
  value       = aws_security_group.alb_public.id
}

output "internal_alb_sg_id" {
  description = "Security group ID for internal ALB"
  value       = aws_security_group.alb_internal.id
}

output "fluentbit_service_account_name" {
  description = "Service account for Fluent Bit"
  value       = kubernetes_service_account.fluent_bit.metadata[0].name
}