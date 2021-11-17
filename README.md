# AWS Haproxy LB

This is a hand-rolled haproxy-backed asg-integrated load balancer intended to
behave similarly to an AWS ELB but allow running on arbitrary instance types
(and thus less cost for non-critical workloads)

## Account-level set up

1. Bake the ami.  In the packer directory, just run `packer build config.json`.
   This currently only builds an AMI in us-west-2
2. Apply the shared terraform. Create and apply a terraform config that looks
   approximately like the below.  `dns_suffix` should be the root of the dns
   where you want to host the load balancers, load balancers will end up with domains like `haproxy-lb-03bbda1dcdff35cc.us-west-2.lb.mytld.com`
```
provider "aws" {
  region  = "us-west-2"
  version = "~> 2.7"

  alias = pdx
}

module "global" {
  source = "github.com/maths22/aws-haproxy//terraform/modules/shared_global"

  dns_suffix = "mytld.com"

  providers = {
    aws = aws.pdx
  }
}

module "shared-us-west-2" {
  source = "github.com/maths22/aws-haproxy//terraform/modules/shared_regional"

  hosted_zone_id = module.global.route53_zone_id

  providers = {
    aws = aws.pdx
  }
}

output "dns_name" {
  value = module.global.route53_name
}

output "name_servers" {
  value = module.global.route53_name_servers
}

```
3. Applying that terraform will output nameservers that must be set for the DNS name

## Load balancer creation
Create load balancers with terraform that looks like the following:

```
module "test-lb" {
  source = "github.com/maths22/aws-haproxy//terraform/modules/haproxy_lb"

  asg_name = "my-asg"
  upstream_port = 80
  health_check_path = "/health_check"

  providers = {
    aws = aws
  }
}

output "lb_dns_name" {
  value = module.test-lb.dns_name
}
```