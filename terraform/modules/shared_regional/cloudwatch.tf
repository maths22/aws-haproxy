
resource "aws_cloudwatch_event_rule" "instance_launch" {
  name = "load_balancer_instance_launch"

  event_pattern = jsonencode({
    detail-type = [
      "EC2 Instance Launch Successful",
      "EC2 Instance Terminate Successful"
    ]
    source      = ["aws.autoscaling"]
  })
}

resource "aws_cloudwatch_event_target" "dns_lambda" {
  rule      = aws_cloudwatch_event_rule.instance_launch.name
  target_id = "SendToDnsLambda"
  arn       = aws_lambda_function.dns.arn
}

resource "aws_cloudwatch_event_target" "target_reload_lambda" {
  rule      = aws_cloudwatch_event_rule.instance_launch.name
  target_id = "SendToTargetReloadLambda"
  arn       = aws_lambda_function.target_reload.arn
}
