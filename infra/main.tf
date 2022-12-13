terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.41"
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

data "aws_caller_identity" "current" {}

resource "aws_cloudtrail" "creds" {
  name           = "tf-creds-trail"
  depends_on     = [aws_s3_bucket_policy.CloudTrailS3BucketPolicy]
  s3_bucket_name = aws_s3_bucket.CloudTrailS3Bucket.id
  advanced_event_selector {
    name = "Log readOnly and writeOnly management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }
}

resource "aws_s3_bucket" "CloudTrailS3Bucket" {
  bucket        = "tf-creds-trail"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "CloudTrailS3BucketPolicy" {
  bucket     = aws_s3_bucket.CloudTrailS3Bucket.id
  depends_on = [aws_s3_bucket.CloudTrailS3Bucket]
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AWSCloudTrailAclCheck",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : "s3:GetBucketAcl",
        "Resource" : "arn:aws:s3:::${aws_s3_bucket.CloudTrailS3Bucket.bucket}"
      },
      {
        "Sid" : "AWSCloudTrailWrite",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : "s3:PutObject",
        "Resource" : [
          "arn:aws:s3:::tf-creds-trail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        ],
        "Condition" : {
          "StringEquals" : {
            "s3:x-amz-acl" : "bucket-owner-full-control"
          }
        }
      }
    ]
    }
  )
}
