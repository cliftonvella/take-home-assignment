resource "aws_acm_certificate" "eks-test-pub-cert" {
  domain_name       = "*.${aws_route53_zone.eks-test-public.name}"
  validation_method = "DNS"

  tags = {
    Name = "${var.project}-${var.env}-${var.instance}"
  }

  lifecycle {
    create_before_destroy = true
  }
}