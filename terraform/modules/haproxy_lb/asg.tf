data "aws_ami" "haproxy" {
  most_recent = true

  filter {
    name   = "name"
    values = ["haproxy-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["self"]
}

data "aws_subnet" "selected" {
  id = split(",", data.aws_autoscaling_group.target_group.vpc_zone_identifier)[0]
}

data "aws_security_group" "ssh_only" {
  name = "ssh-only"
  vpc_id = data.aws_subnet.selected.vpc_id
}

data "aws_security_group" "http" {
  name = "http"
  vpc_id = data.aws_subnet.selected.vpc_id
}

resource "aws_security_group" "lb_reload" {
  name        = "haproxy_lb_reload-${random_id.lb_id.hex}"
  description = "Allow haproxy reloader traffic"
  vpc_id      = data.aws_subnet.selected.vpc_id

  ingress {
    from_port   = 91
    to_port     = 91
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

locals {
  dns_name = "haproxy-lb-${random_id.lb_id.hex}.${data.aws_region.current.name}.${data.aws_ssm_parameter.dns_suffix.value}"
}

resource "aws_launch_template" "lb_config" {
  name          = "haproxy"
  image_id      = data.aws_ami.haproxy.id
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  key_name = "SSH"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [
      data.aws_security_group.ssh_only.id,
      data.aws_security_group.http.id,
      aws_security_group.lb_reload.id
    ]
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      encrypted   = "false"
      volume_size = 8
    }
  }

  user_data = base64encode(jsonencode({
    asg_name: var.asg_name
    port: var.upstream_port
    health_check_path: var.health_check_path
  }))
}

resource "aws_autoscaling_group" "lb_asg" {
  name = "haproxy-lb-${random_id.lb_id.hex}"
  launch_template {
    name    = aws_launch_template.lb_config.name
    version = "$Latest"
  }
  min_size = 1
  max_size = 3

  vpc_zone_identifier = split(",", data.aws_autoscaling_group.target_group.vpc_zone_identifier)

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Role"
    value               = "Haproxy"
    propagate_at_launch = true
  }

  tag {
    key = "SourceGroup"
    value = var.asg_name
    propagate_at_launch = false
  }

  tag {
    key = "DNSName"
    value = local.dns_name
    propagate_at_launch = false
  }
}
