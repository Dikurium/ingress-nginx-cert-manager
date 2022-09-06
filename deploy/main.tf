terraform {
  cloud {
    organization = "Dikurium_Swiss_Consulting"
    workspaces {
      name = "ingress-nginx-cert-manager"
    }
  }
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.1"
    }
    kustomization = {
      source  = "kbst/kustomization"
      version = "0.9.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "my-context"
}

provider "kustomization" {
  alias           = "local_kube"
  kubeconfig_path = "~/.kube/config"
}

module "nginx" {
  providers = {
    kustomization = kustomization.local_kube
  }

  source  = "kbst.xyz/catalog/nginx/kustomization"
  version = "1.2.1-kbst.0"

  configuration_base_key = "default"
  configuration = {
    default = {
      namespace = "nginx-ingress"
      patches = [
        {
          patch = <<-EOF
          apiVersion: v1
          kind: Service
          metadata:
            labels:
              service.beta.kubernetes.io/do-loadbalancer-name: nginx-ingress-controller.service.dikurium.ch
            name: ingress-nginx-controller
            namespace: ingress-nginx
        EOF

          target = {
            group     = ""
            version   = "v1"
            kind      = "Service"
            name      = "ingress-nginx-controller"
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

  configuration_base_key = "default"
  configuration = {
    default = {
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
