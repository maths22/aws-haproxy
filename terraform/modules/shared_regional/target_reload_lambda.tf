data "archive_file" "target_reload_lambda_archive" {
  type        = "zip"
  source_file = "${path.module}/target_reload_lambda/handler.rb"
  output_path = "${path.module}/target_reload_lambda.zip"
}

resource "aws_lambda_permission" "allow_target_reload_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.target_reload.function_name
  principal     = "events.${data.aws_partition.current.dns_suffix}"
  source_arn    = aws_cloudwatch_event_rule.instance_launch.arn
}

data "aws_iam_policy_document" "target_reload_lambda_log_policy" {
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

resource "aws_iam_role_policy" "target_reload_lambda_log_policy" {
  policy = data.aws_iam_policy_document.target_reload_lambda_log_policy.json
  role   = aws_iam_role.target_reload_lambda_role.id
}

data "aws_iam_policy_document" "target_reload_reource_policy" {
  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    actions   = ["autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeTags"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "target_reload_reource_policy" {
  policy = data.aws_iam_policy_document.target_reload_reource_policy.json
  role   = aws_iam_role.target_reload_lambda_role.id
}

resource "aws_iam_role" "target_reload_lambda_role" {
  name = "haproxy-lb-target_reload-lambda-role"

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

resource "aws_lambda_function" "target_reload" {
  filename      = data.archive_file.target_reload_lambda_archive.output_path
  function_name = "haproxy-lb-target_reload-lambda"
  role          = aws_iam_role.target_reload_lambda_role.arn
  handler       = "handler.lambda_handler"

  source_code_hash = data.archive_file.target_reload_lambda_archive.output_base64sha256

  runtime = "ruby2.5"

  tags = local.tags
}