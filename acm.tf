# resource "aws_acm_certificate" "sandbox-pub-cert" {
#   domain_name       = "*.${aws_route53_zone.sandbox-public.name}"
#   validation_method = "DNS"

#   tags = {
#     Name = "${var.project}-${var.env}-${var.instance}"
#   }

#   lifecycle {
#     create_before_destroy = true
#   }
# }
