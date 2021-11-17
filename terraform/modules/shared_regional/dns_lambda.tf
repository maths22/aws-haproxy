data "archive_file" "dns_lambda_archive" {
  type        = "zip"
  source_file = "${path.module}/dns_lambda/handler.rb"
  output_path = "${path.module}/dns_lambda.zip"
}

resource "aws_lambda_permission" "allow_dns_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dns.function_name
  principal     = "events.${data.aws_partition.current.dns_suffix}"
  source_arn    = aws_cloudwatch_event_rule.instance_launch.arn
}

data "aws_iam_policy_document" "dns_lambda_log_policy" {
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
  }
}

resource "aws_iam_role_policy" "dns_lambda_log_policy" {
  policy = data.aws_iam_policy_document.dns_lambda_log_policy.json
  role   = aws_iam_role.dns_lambda_role.id
}

data "aws_iam_policy_document" "dns_reource_policy" {
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    actions   = ["autoscaling:DescribeAutoScalingGroups"]
    resources = ["*"]
  }

  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = ["arn:${data.aws_partition.current.partition}:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

resource "aws_iam_role_policy" "dns_reource_policy" {
  policy = data.aws_iam_policy_document.dns_reource_policy.json
  role   = aws_iam_role.dns_lambda_role.id
}

resource "aws_iam_role" "dns_lambda_role" {
  name = "haproxy-lb-dns-lambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = local.tags
}

resource "aws_lambda_function" "dns" {
  filename      = data.archive_file.dns_lambda_archive.output_path
  function_name = "haproxy-lb-dns-lambda"
  role          = aws_iam_role.dns_lambda_role.arn
  handler       = "handler.lambda_handler"

  source_code_hash = data.archive_file.dns_lambda_archive.output_base64sha256

  runtime = "ruby2.7"

  environment {
    variables = {
      hosted_zone_id = var.hosted_zone_id
    }
  }

  tags = local.tags
}