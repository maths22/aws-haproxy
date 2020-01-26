data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  tags = {
    Project     = "Haproxy-lb"
  }
}

data "aws_route53_zone" "zone" {
  zone_id = var.hosted_zone_id
}

resource "aws_ssm_parameter" "dns_name_store" {
  name  = "/haproxy_lb/dns_suffix"
  type  = "String"
  value = data.aws_route53_zone.zone.name
}
