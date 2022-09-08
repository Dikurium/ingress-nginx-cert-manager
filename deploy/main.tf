terraform {
  cloud {
    organization = "Dikurium_Swiss_Consulting"
    workspaces {
      name = "ingress-nginx-cert-manager"
    }
  }
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
  domain = "dikurium.ch"
}

provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_kubernetes_cluster" "dikurium_kube_cluster" {
  name = var.dikurium_k8s_cluster_name_all
}

provider "kustomization" {
  alias          = "local_kube"
  kubeconfig_raw = data.digitalocean_kubernetes_cluster.dikurium_kube_cluster.kube_config[0].raw_config
}

module "nginx" {
  providers = {
    kustomization = kustomization.local_kube
  }

  source  = "kbst.xyz/catalog/nginx/kustomization"
  version = "1.2.1-kbst.0"

  configuration_base_key = "ingress-nginx-cert-manager"
  configuration = {
    ingress-nginx-cert-manager = {
      namespace = "nginx-ingress"
      patches = [
        {
          patch = <<-EOF
          apiVersion: v1
          kind: Service
          metadata:
            annotations:
              service.beta.kubernetes.io/do-loadbalancer-name: nginx-ingress-controller.service.dikurium.ch
              service.beta.kubernetes.io/do-loadbalancer-hostname: ${local.domain}
            name: ingress-nginx-controller
            namespace: ingress-nginx
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
  providers = {
    kustomization = kustomization.local_kube
  }

  source  = "kbst.xyz/catalog/cert-manager/kustomization"
  version = "1.8.2-kbst.0"

  configuration_base_key = "ingress-nginx-cert-manager"
  configuration = {
    ingress-nginx-cert-manager = {
      additional_resources = ["${path.root}/manifests/cluster-issuer.yaml"]
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

data "digitalocean_loadbalancer" "nginx-ingress-controller" {
  name = "nginx-ingress-controller.service.dikurium.ch"
}

resource "digitalocean_domain" "dikurium" {
  name       = "@"
  ip_address = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}
