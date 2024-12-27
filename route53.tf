# Get public zone for this environment
resource "aws_route53_zone" "eks-test-public" {
  name = "${var.env_alias[var.env]}.${var.project}.${var.instance}.ekstest.com"
}