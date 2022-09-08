output "nginx-ingress-controller-ip" {
  value = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}
