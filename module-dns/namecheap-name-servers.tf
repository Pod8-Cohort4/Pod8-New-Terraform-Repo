# resource "namecheap_domain_records" "hijoacloud_online" {
#   domain = var.domain-name
#   mode = "OVERWRITE" // Warning: this will remove all manually set records

# nameservers = aws_route53_zone.r53_zone.name_servers
# depends_on = [ aws_route53_zone.r53_zone ]
# }