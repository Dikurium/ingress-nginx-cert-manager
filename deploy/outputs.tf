output "nginx_ingress_loadbalancer_name" {
  description = "Name of the DigitalOcean LoadBalancer deployed for the Nginx Ingress controller"
  value       = local.nginx_controller_service_name
}

output "nginx_ingress_controller_ip" {
  description = "IP of the DigitalOcean LoadBalancer for the Nginx Ingress controller"
  value       = data.digitalocean_loadbalancer.nginx-ingress-controller.ip
}

output "domain_id" {
  description = "ID of the domain created in DigitalOcean"
  value       = digitalocean_domain.domain.id
}

output "root_fqdn" {
  description = "Root FQDN"
  value       = digitalocean_domain.domain.name
}

output "www_fqdn" {
  description = "www FQDN"
  value       = digitalocean_record.www.fqdn
}

output "workaround_fqdn" {
  description = "FQDN used for the Nginx Ingress configuration workaround required by DigitalOcean"
  value       = digitalocean_record.workaround.fqdn
}
