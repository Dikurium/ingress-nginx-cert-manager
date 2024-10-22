variable "do_token" {
  description = "DigitalOcean API Access Token"
  type        = string
  sensitive   = true
}

variable "domain" {
  description = "Root domain for Ingress configuration"
  type        = string
}

variable "dikurium_k8s_cluster_name_all" {
  description = "The name of the Dikurium main Kubernetes cluster"
  default     = "k8s-dik-all"
  type        = string
}
