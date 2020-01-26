resource "aws_route53_zone" "proxy" {
  name         = "lb.${var.dns_suffix}"
}