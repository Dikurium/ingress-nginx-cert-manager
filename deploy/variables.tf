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
