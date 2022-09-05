# local-ingress-nginx

Nginx Ingress Controller configuration for Kubernetes using Kubestack and Terraform.

Included in this configuration:

- [`nginx-ingress`](https://www.kubestack.com/catalog/nginx/)
- [`cert-manager`](https://www.kubestack.com/catalog/cert-manager/) with Let's Encrypt

This module also includes an example for merging custom labels and disabling Let's Encrypt (using the staging API) in GitOps flows.
