terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# Data source to get EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Data source to get the OIDC provider ARN
data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# SNS topic
resource "aws_sns_topic" "ecr_events" {
  name = "${var.repo_name}-ecr-events"
  tags = var.tags
}

# IAM Role for EventBridge to publish to SNS
resource "aws_iam_role" "eventbridge_to_sns" {
  name = "${var.repo_name}-eventbridge-sns-role"

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

# IAM Role for SNS EventSource (to be used with IRSA)
resource "aws_iam_role" "sns_eventsource_role" {
  name = "${var.repo_name}-sns-eventsource-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.cluster.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.cluster.arn, "/^.*oidc-provider\\//", "")}:sub" = "system:serviceaccount:${var.argo_namespace}:argo-workflows-server"
          "${replace(data.aws_iam_openid_connect_provider.cluster.arn, "/^.*oidc-provider\\//", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

# Policy for EventSource to manage SQS and subscribe to SNS
resource "aws_iam_role_policy" "sns_eventsource_policy" {
  name = "SNSEventSourcePolicy"
  role = aws_iam_role.sns_eventsource_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ListQueues"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:GetTopicAttributes"
        ]
        Resource = aws_sns_topic.ecr_events.arn
      }
    ]
  })
}

# EventBridge rule to catch ECR push events
resource "aws_cloudwatch_event_rule" "ecr_push" {
  name        = "${var.repo_name}-ecr-push-rule"
  description = "Capture ECR image push events for ${var.repo_name}"
  event_pattern = jsonencode({
    "source" : ["aws.ecr"],
    "detail-type" : ["ECR Image Action"],
    "detail" : {
      "repository-name" : ["${var.repo_name}"],
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
    namespace             = var.argo_namespace
    aws_region            = var.aws_region
    sns_topic_arn         = aws_sns_topic.ecr_events.arn
    aws_creds_secret_name = var.aws_creds_secret_name
  })
}

resource "kubectl_manifest" "sns_sensor" {
  yaml_body = templatefile("${path.module}/sns-sensor.yaml.tmpl", {
    namespace             = var.argo_namespace
    target_node_host_path = var.target_node_host_path
    ecr_repo_url          = var.ecr_repo_url
    region                = var.aws_region
  })
}

# Output the role ARN for reference
output "sns_eventsource_role_arn" {
  description = "ARN of the IAM role for SNS EventSource"
  value       = aws_iam_role.sns_eventsource_role.arn
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = data.aws_iam_openid_connect_provider.cluster.arn
}