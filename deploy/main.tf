terraform {
  cloud {
    organization = "Dikurium_Swiss_Consulting"
    workspaces {
      name = "dikurium-ingress-nginx-cert-manager"
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
    helm = {
      source  = "hashicorp/helm"
      version = "2.6.0"
    }
  }
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_kubernetes_cluster" "dikurium_kube_cluster" {
  name = var.dikurium_k8s_cluster_name_all
}

locals {
  workaround_fqdn               = "workaround.${var.domain}"
  nginx_controller_service_name = "nginx-ingress-controller.service.${var.domain}"
}

provider "kustomization" {
  kubeconfig_raw = data.digitalocean_kubernetes_cluster.dikurium_kube_cluster.kube_config[0].raw_config
}

provider "helm" {
  kubernetes {
    host                   = data.digitalocean_kubernetes_cluster.dikurium_kube_cluster.endpoint
    token                  = data.digitalocean_kubernetes_cluster.dikurium_kube_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(data.digitalocean_kubernetes_cluster.dikurium_kube_cluster.kube_config[0].cluster_ca_certificate)
  }
}

module "nginx" {
  source  = "kbst.xyz/catalog/nginx/kustomization"
  version = "1.10.1-kbst.0"

  configuration_base_key = terraform.workspace
  configuration = {
    "${terraform.workspace}" = {
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
        },
        {
          patch = yamlencode([
            {
              op   = "add"
              path = "/data"
              value = {
                "allow-snippet-annotations" = "true"
                "use-http2"                 = "true"
              }
            },
            {
              op    = "add"
              path  = "/data/http-snippet"
              value = <<-EOF
                # Drop LeakIX scanner globally
                map $http_user_agent $block_leakix {
                  default 0;
                  ~*l9scan 1;
                }

                # Drop OPTIONS fuzzing like /?/?/?/
                map "$request_method:$request_uri" $block_bad_options {
                  default 0;
                  ~^OPTIONS:/\\?/ 1;
                }
              EOF
            },
            {
              op    = "add"
              path  = "/data/server-snippet"
              value = <<-EOF
                if ($block_leakix) {
                  return 444;
                }

                if ($block_bad_options) {
                  return 444;
                }
              EOF
            },
          ])

          target = {
            group   = ""
            version = "v1"
            kind    = "ConfigMap"
            name    = "ingress-nginx-controller"
          }
        }
      ]
    }
  }
}

module "cert_manager" {
  source  = "kbst.xyz/catalog/cert-manager/kustomization"
  version = "1.15.0-beta.2-kbst.0"

  configuration_base_key = terraform.workspace
  configuration = {
    "${terraform.workspace}" = {
      additional_resources = [
        "${path.root}/manifests/dik-cluster-issuer.yaml",
        "${path.root}/manifests/ip-cluster-issuer.yaml",
        "${path.root}/manifests/fundp-cluster-issuer.yaml",
        "${path.root}/manifests/finly-cluster-issuer.yaml",
        "${path.root}/manifests/peerly-cluster-issuer.yaml",
        "${path.root}/manifests/finpath-cluster-issuer.yaml",
      ]
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

resource "helm_release" "cert_manager_csi" {
  name       = "cert-manager-csi"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io/"
  chart      = "cert-manager-csi-driver"
  version    = "0.10.1"

  values = [yamlencode({
    nodeSelector = {
      service  = "main"
      priority = "high"
    }
  })]
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
  name = var.domain
  # ip_address = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
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
