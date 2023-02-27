terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
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

resource "aws_iam_role" "ddb_lambda_role" {
  name = "tf-creds-ddb-lambda-iam-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
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
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  ])
  role       = aws_iam_role.ddb_lambda_role.name
  policy_arn = each.value
}

resource "aws_lambda_function" "lambda_function" {
  filename      = "lambda_function_payload.zip"
  function_name = "start_query"
  role          = aws_iam_role.ddb_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cloudwatch_event_rule.arn
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name             = "tf-creds-dynamodb-table"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "date"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "date"
    type = "S"
  }
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
    "eds-arn" : aws_cloudtrail_event_data_store.cloudtrail_event_data_store.arn,
    "table" : aws_dynamodb_table.dynamodb_table.name
  })
}

resource "aws_elasticsearch_domain" "elasticsearch_domain" {
  domain_name           = "tf-creds-es-domain"
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type = "t3.small.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "elasticsearch"
      master_user_password = "ElasticSearch1!" # gitleaks:allow
    }
  }
}

resource "aws_elasticsearch_domain_policy" "elasticsearch_domain_policy" {
  domain_name = aws_elasticsearch_domain.elasticsearch_domain.domain_name

  access_policies = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "*"
          },
          "Action" : "es:*",
          "Resource" : "${aws_elasticsearch_domain.elasticsearch_domain.arn}/*"
        }
      ]
  })
}

resource "aws_iam_role" "opensearch_lambda_role" {
  name = "tf-creds-opensearch-lambda-role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "opensearch_lambda_policy" {
  name = "tf-creds-opensearch-lambda-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "es:ESHttpPost",
          "es:ESHttpPut",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "opensearch_lambda_policy_attachment" {
  name       = "tf-creds-opensearch-lambda-policy-attachment"
  roles      = [aws_iam_role.opensearch_lambda_role.name]
  policy_arn = aws_iam_policy.opensearch_lambda_policy.arn
}
