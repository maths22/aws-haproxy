data "aws_iam_policy_document" "asg_access" {
  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "ec2:DescribeInstances"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  name = "haproxy-lb-${random_id.lb_id.hex}-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = var.tags
}

resource "aws_iam_role_policy" "asg_access" {
  role   = aws_iam_role.ec2_instance_role.name
  policy = data.aws_iam_policy_document.asg_access.json
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "haproxy-lb-${random_id.lb_id.hex}-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}
