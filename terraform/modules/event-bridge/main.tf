terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

# SNS topic
resource "aws_sns_topic" "ecr_events" {
  name = "${var.ecr_repo_name}-ecr-events"
  tags = var.tags
}

# IAM Role for EventBridge to publish to SNS
resource "aws_iam_role" "eventbridge_to_sns" {
  name = "${var.ecr_repo_name}-eventbridge-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM policy to allow publish to SNS
resource "aws_iam_role_policy" "allow_publish" {
  name = "AllowPublishToSNS"
  role = aws_iam_role.eventbridge_to_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.ecr_events.arn
    }]
  })
}

# EventBridge rule to catch ECR push events
resource "aws_cloudwatch_event_rule" "ecr_push" {
  name        = "${var.ecr_repo_name}-ecr-push-rule"
  description = "Capture ECR image push events for ${var.ecr_repo_name}"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "repository-name" : [var.ecr_repo_name],
      "action-type" : ["PUSH"]
    }
  })
}

# EventBridge target: SNS topic
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.ecr_push.name
  target_id = "sns-target"
  arn       = aws_sns_topic.ecr_events.arn
  role_arn  = aws_iam_role.eventbridge_to_sns.arn
}

# Allow EventBridge to invoke SNS
resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = aws_sns_topic.ecr_events.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.ecr_events.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.ecr_push.arn
          }
        }
      }
    ]
  })
}

resource "kubectl_manifest" "sns_eventsource" {
  yaml_body = templatefile("${path.module}/sns-eventsource.yaml.tmpl", {
    namespace             = "argo"
    aws_region            = var.aws_region
    sns_topic_arn         = aws_sns_topic.ecr_events.arn
    aws_creds_secret_name = var.aws_creds_secret_name
  })
}

