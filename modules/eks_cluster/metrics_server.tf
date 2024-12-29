# This is a pre-requisite for the HPA to work. The metrics-server is a cluster-wide aggregator of resource usage data. 
# It collects metrics from the Summary API, exposed by Kubelet on each node. The metrics are stored in memory and are 
# served from the /metrics endpoint on the metrics-server's API. The metrics-server is not meant for long-term storage 
# of metrics, therefore it is not a substitute for a monitoring solution like Cloudwatch / Prometheus.

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls}" # Might be required in dev/test environments, not recommended for production
  }
}