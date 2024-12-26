# Public zone for this environment
resource "aws_route53_zone" "sandbox-public" {
  name = "${var.env_alias[var.env]}.${var.project}.${var.instance}.sandbox.com"
}