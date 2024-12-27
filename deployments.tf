# Deployment
resource "kubernetes_deployment" "httpbin" {
  metadata {
    name = "httpbin"
    labels = {
      app = "httpbin"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "httpbin"
      }
    }

    template {
      metadata {
        labels = {
          app = "httpbin"
        }
      }

      spec {
        container {
          name  = "httpbin"
          image = "kennethreitz/httpbin"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/get"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          readiness_probe {
            http_get {
              path = "/get"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

# Public Service
resource "kubernetes_service" "httpbin_public" {
  metadata {
    name = "httpbin-public"
  }

  spec {
    selector = {
      app = kubernetes_deployment.httpbin.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

# Internal Service
resource "kubernetes_service" "httpbin_internal" {
  metadata {
    name = "httpbin-internal"
  }

  spec {
    selector = {
      app = kubernetes_deployment.httpbin.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

# Public Ingress
resource "kubernetes_ingress_v1" "httpbin_public" {
  metadata {
    name = "httpbin-public"
    annotations = {
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/certificate-arn"    = aws_acm_certificate.eks-test-pub-cert.arn
      "alb.ingress.kubernetes.io/security-groups"    = module.eks_cluster.public_alb_sg_id
      "alb.ingress.kubernetes.io/ssl-policy"         = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
      "alb.ingress.kubernetes.io/subnets"            = join(",", module.lb_subnets.subnets[*].id)
      "alb.ingress.kubernetes.io/load-balancer-name" = "httpbin-public"
      "alb.ingress.kubernetes.io/group.name"         = "httpbin"
    }
  }

  spec {
    rule {
      host = "app.${aws_route53_zone.eks-test-public.name}"
      http {
        path {
          path      = "/get"
          path_type = "Exact"
          backend {
            service {
              name = kubernetes_service.httpbin_public.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Data source to get the public ALB DNS name
data "aws_lb" "ingress-public" {
  tags = {
    "ingress.k8s.aws/stack" = "httpbin-public" # This tag is added by ALB controller
  }

  depends_on = [kubernetes_ingress_v1.httpbin_public]
}

# Route53 record
resource "aws_route53_record" "app-public" {
  zone_id = aws_route53_zone.eks-test-public.zone_id
  name    = "app"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress-public.dns_name
    zone_id                = data.aws_lb.ingress-public.zone_id
    evaluate_target_health = false
  }
}

# Internal Ingress
resource "kubernetes_ingress_v1" "httpbin_internal" {
  metadata {
    name = "httpbin-internal"
    annotations = {
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/scheme"             = "internal"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/listen-ports"       = jsonencode([{ "HTTP" : 80 }])
      "alb.ingress.kubernetes.io/security-groups"    = module.eks_cluster.internal_alb_sg_id
      "alb.ingress.kubernetes.io/subnets"            = join(",", module.lb_subnets_internal.subnets[*].id)
      "alb.ingress.kubernetes.io/load-balancer-name" = "httpbin-internal"
      "alb.ingress.kubernetes.io/group.name"         = "httpbin"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/post"
          path_type = "Exact"
          backend {
            service {
              name = kubernetes_service.httpbin_internal.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Data source to get the internal ALB DNS name
data "aws_lb" "ingress-internal" {
  tags = {
    "ingress.k8s.aws/stack" = "httpbin-internal" # This tag is added by ALB controller
  }

  depends_on = [kubernetes_ingress_v1.httpbin_internal]
}

# Route53 record
resource "aws_route53_record" "app-internal" {
  zone_id = module.vpc.phz.id
  name    = "app"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress-internal.dns_name
    zone_id                = data.aws_lb.ingress-internal.zone_id
    evaluate_target_health = false
  }
}