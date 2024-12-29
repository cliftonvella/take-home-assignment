# Deployment
resource "kubernetes_deployment" "httpbin" {
  metadata {
    name = "httpbin"
    labels = {
      app = "httpbin"
    }
  }

  spec {
    replicas = 3 # Increased to 3 replicas for better redundancy

    selector {
      match_labels = {
        app = "httpbin"
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1 # Allow one additional pod to be created during a rolling update
        max_unavailable = 0 # Don't allow any pods to be unavailable during a rolling update
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
            requests = { # Minimum resources guaranteed to a container
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {         # Maximum resources a container can use
              cpu    = "500m"  # Throttle the CPU usage if over 500m (0.5 cores)
              memory = "512Mi" # Throttle, and then kill if the memory usage goes over 512Mi
            }
          }

          liveness_probe { # Check if the container is alive and healthy. If it fails, the container is restarted
            http_get {
              path = "/get"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }

          readiness_probe { # Check if the container is ready to serve traffic. If it fails, the container is removed from the service
            http_get {
              path = "/get"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
        # Fluent Bit sidecar container
        container {
          name  = "fluent-bit"
          image = "fluent/fluent-bit:1.9"

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/"
            read_only  = true
          }

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }
        }

        # Host path volume for container logs
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        # ConfigMap volume for Fluent Bit configuration
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluent_bit.metadata[0].name
          }
        }
        # Required IAM permissions for CloudWatch access
        service_account_name = module.eks_cluster.fluentbit_service_account_name
      }
    }
  }
}

# Fluent Bit ConfigMap
resource "kubernetes_config_map" "fluent_bit" {
  metadata {
    name = "fluent-bit-config"
  }

  data = {
    "fluent-bit.conf" = <<EOF
[SERVICE]
    Daemon Off
    Flush 1
    Log_Level info

[INPUT]
    Name tail
    Path /var/log/containers/*.log
    Parser docker
    Tag kube.*
    Refresh_Interval 5

[FILTER]
    Name kubernetes
    Match kube.*
    Merge_Log On
    Keep_Log Off
    K8S-Logging.Parser On
    K8S-Logging.Exclude On

[OUTPUT]
    Name cloudwatch
    Match kube.*
    region ${var.aws_region}
    log_group_name /eks/${var.cluster_name}/httpbin
    log_stream_prefix container-
    auto_create_group true
EOF

    "parsers.conf" = <<EOF
[PARSER]
    Name docker
    Format json
    Time_Key time
    Time_Format %Y-%m-%dT%H:%M:%S.%L
EOF
  }
}

# Public Service
resource "kubernetes_service" "httpbin_public" {
  metadata {
    name = "httpbin-public"
    labels = {
      app    = kubernetes_deployment.httpbin.metadata[0].labels.app
      access = "public"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.httpbin.metadata[0].labels.app
    }

    port { # Traffic -> Service (port 80) -> Pod (target_port 80)
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
    labels = {
      app    = kubernetes_deployment.httpbin.metadata[0].labels.app
      access = "internal"
    }
  }

  spec {
    selector = {
      app = kubernetes_deployment.httpbin.metadata[0].labels.app
    }

    port { # Traffic -> Service (port 80) -> Pod (target_port 80)
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  }
}

# Public Ingress - Deploys an internet-facing ALB which routes traffic to the /get endpoint of the httpbin service
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

# Route53 record for the ALB on the R53 public zone
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

# Internal Ingress - Deploys an internal ALB which routes traffic to the /post endpoint of the httpbin service
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
      host = "app.${module.vpc.phz.name}"
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

# Route53 record for the ALB on the private hosted zone
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

# Network Policy
resource "kubernetes_network_policy" "httpbin" {
  metadata {
    name = "httpbin-network-policy"
  }

  spec {
    pod_selector { # Select the pods to which this policy applies
      match_labels = {
        app = kubernetes_deployment.httpbin.metadata[0].labels.app
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        # Additional security layer at cluster level to allow access to the pods only from within the VPC 
        ip_block {
          cidr = module.vpc.vpc.cidr_block
        }
      }
      ports {
        port     = 80
        protocol = "TCP"
      }
    }

    # Allow traffic to /post endpoint only from internal namespaces
    ingress {
      from {
        # This is a placeholder for a namespace selector, which can for example allow access to the httpbin pods only from pods in the selected namespaces
        namespace_selector {
          match_labels = {
            environment = "internal"
          }
        }
      }
      ports {
        port     = 80
        protocol = "TCP"
      }
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "httpbin" {
  metadata {
    name = "httpbin-hpa"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.httpbin.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 60
        select_policy                = "Max"
        policy {
          type           = "Pods"
          value          = 4
          period_seconds = 60
        }
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 60
        }
      }
      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"
        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 60
        }
        policy {
          type           = "Percent"
          value          = 10
          period_seconds = 60
        }
      }
    }
  }
}
