# output "nginx_ingress_lb_dns" {
#   value = data.aws_lb.nginx_ingress.dns_name
# }

# output "nginx_lb_ip" {
#   value = data.aws_lb.nginx_ingress.ip_address_type == "ipv4" ? data.aws_lb.nginx_ingress.dns_name : ""
# }
# output "nginx_ingress_load_balancer_hostname" {
#   value = data.aws_lb.nginx_ingress.dns_name
# }


output "nginx_ingress_lb_dns" {
  value = local.nginx_ingress_dns
}

output "nginx_lb_ip" {
  value = local.nginx_ingress_ip
}

output "nginx_ingress_load_balancer_hostname" {
  value = local.nginx_ingress_dns
}


