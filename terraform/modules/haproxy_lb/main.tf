data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "random_id" "lb_id" {
  byte_length = 8
}

data "aws_autoscaling_group" "target_group" {
  name = var.asg_name
}

data "aws_ssm_parameter" "dns_suffix" {
  name = "/haproxy_lb/dns_suffix"
}
