variable "workspace" {
  description = "Terraform workspace to use for Kubestack configuration key"
  type        = string
}

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

variable "dikurium_k8s_pool_name" {
  description = "The name of the Dikurium main Kubernetes pool"
  default     = "pool-dik-all"
  type        = string
}

variable "cert_manager_additional_resources" {
  description = "Additional resources to add to the Cert-Manager deployment, such as a ClusterIssuer"
  type        = list(string)
}
