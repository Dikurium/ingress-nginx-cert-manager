terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
  }
}

locals {
  workaround_fqdn               = "workaround.${var.domain}"
  nginx_controller_service_name = "nginx-ingress-controller.service.${var.domain}"
}

module "nginx" {
  source  = "kbst.xyz/catalog/nginx/kustomization"
  version = "1.2.1-kbst.0"

  configuration_base_key = var.workspace
  configuration = {
    "${var.workspace}" = {
      namespace = "nginx-ingress"
      patches = [
        {
          patch = <<-EOF
          apiVersion: v1
          kind: Service
          metadata:
            annotations:
              service.beta.kubernetes.io/do-loadbalancer-name: ${local.nginx_controller_service_name}
              service.beta.kubernetes.io/do-loadbalancer-hostname: ${local.workaround_fqdn}
            name: ingress-nginx-controller
            namespace: ingress-nginx
        EOF

          target = {
            group   = ""
            version = "v1"
            kind    = "Service"
            name    = "ingress-nginx-controller"
          }
        },
        {
          patch = <<-EOF
          - op: replace
            path: /spec/externalTrafficPolicy
            value: Cluster
        EOF

          target = {
            group   = ""
            version = "v1"
            kind    = "Service"
            name    = "ingress-nginx-controller"
          }
        }
      ]
    }
  }
}

module "cert_manager" {
  source  = "kbst.xyz/catalog/cert-manager/kustomization"
  version = "1.8.2-kbst.0"

  configuration_base_key = var.workspace
  configuration = {
    "${var.workspace}" = {
      additional_resources = var.cert_manager_additional_resources
    }
    ops = {
      patches = [
        {
          patch = <<-EOF
          - op: replace
            path: /spec/acme/server
            value: https://acme-staging-v02.api.letsencrypt.org/directory
        EOF

          target = {
            group   = "cert-manager.io"
            version = "v1"
            kind    = "ClusterIssuer"
            name    = "letsencrypt"
          }
        }
      ]
    }
  }
}

resource "time_sleep" "wait_for_loadbalancer" {
  depends_on = [
    module.nginx
  ]
  create_duration = "30s"
}

data "digitalocean_loadbalancer" "nginx-ingress-controller" {
  name = local.nginx_controller_service_name
  depends_on = [
    time_sleep.wait_for_loadbalancer
  ]
}

resource "digitalocean_domain" "domain" {
  name       = var.domain
  ip_address = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}

resource "digitalocean_record" "www" {
  domain = digitalocean_domain.domain.id
  type   = "A"
  name   = "www"
  value  = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}

resource "digitalocean_record" "workaround" {
  domain = digitalocean_domain.domain.id
  type   = "A"
  name   = "workaround"
  value  = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}
