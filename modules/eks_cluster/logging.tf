# Service Account for Fluent Bit
resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name = "fluent-bit"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
    }
  }
}