terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.45.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = merge(var.tags, { User = var.user })
  }
}


resource "random_id" "server" {
  byte_length = 8
}

resource "aws_cloudtrail_event_data_store" "cloudtrail_event_data_store" {
  name                           = "tf-creds-cloudtrail-eds-${random_id.server.hex}"
  termination_protection_enabled = false
  multi_region_enabled           = true
  retention_period               = 7
}

output "cloudtrail_event_data_store_id" {
  value = aws_cloudtrail_event_data_store.cloudtrail_event_data_store.arn
}


resource "aws_iam_role" "iam_role" {
  name = "tf-creds-iam-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AWSCloudTrail_FullAccess",
  ])
  role       = aws_iam_role.iam_role.name
  policy_arn = each.value
}

resource "aws_lambda_function" "lambda_function" {
  filename      = "lambda_function_payload.zip"
  function_name = "start_query"
  role          = aws_iam_role.iam_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule" {
  name                = "tf-creds-cloudwatch-event-rule"
  description         = "Trigger lanbda query once a day"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_target" {
  arn  = aws_lambda_function.lambda_function.arn
  rule = aws_cloudwatch_event_rule.cloudwatch_event_rule.id
  input = jsonencode({
    "eds-urn" : aws_cloudtrail_event_data_store.cloudtrail_event_data_store.arn
  })
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_event_rule.arn
}
