output "nginx-ingress-controller-ip" {
  value = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}

output "root_fqdn" {
  value = digitalocean_domain.dikurium.name
}

output "www_fqdn" {
  value = digitalocean_record.www.fqdn
}

output "workaround_fqdn" {
  value = digitalocean_record.workaround.fqdn
}
