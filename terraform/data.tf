# data.tf
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2", "amzn-ami-hvm-*-x86_64-gp2"]
  }
}


# Data source para obtener la cuenta actual
data "aws_caller_identity" "current" {}

# Documento de política IAM para Lambda
data "aws_iam_policy_document" "lambda_policy" {
  # Permisos para SQS
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.alarm_queue.arn]
  }

  # Permisos para SNS
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish"
    ]
    resources = [aws_sns_topic.sns_topic.arn]
  }

  # Permisos para CloudWatch Logs
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"]
  }
}
# Documento de política IAM para EC2
data "aws_iam_policy_document" "ec2_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.app_logs.arn,
      "${aws_cloudwatch_log_group.app_logs.arn}:*"    ]
  }
}