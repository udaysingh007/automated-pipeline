variable "namespace" {
  description = "Namespace where argo-events and argod-workflows are deployed"
  type        = string
}

variable "node_selector_key" {
  description = "Node selector key for EventBus placement"
  type        = string
  default     = "kubernetes.io/hostname"
}

variable "node_selector_value" {
  description = "Node selector value for EventBus placement"
  type        = string
  # Set this to your specific node name or label value
}

resource "kubernetes_manifest" "eventbus" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "EventBus"
    metadata = {
      name      = "default"
      namespace = "${var.namespace}"
    }
    spec = {
      nats = {
        native = {
          replicas = 1
          auth     = "none"
          nodeSelector = {
            "${var.node_selector_key}" = "${var.node_selector_value}"
          }
          containerTemplate = {
            volumeMounts = [
              {
                name      = "nats-data"
                mountPath = "/data"
              }
            ]
          }
          volumes = [
            {
              name = "nats-data"
              hostPath = {
                path = "/var/lib/nats-eventbus"
                type = "DirectoryOrCreate"
              }
            }
          ]
        }
      }
    }
  }
}
