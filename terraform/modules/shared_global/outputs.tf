output "route53_name" {
  value = aws_route53_zone.proxy.name
}

output "route53_zone_id" {
  value = aws_route53_zone.proxy.zone_id
}

output "route53_name_servers" {
  value = aws_route53_zone.proxy.name_servers
}
