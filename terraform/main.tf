terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "data_lake" {
  bucket = "gittrends-data-lake" 
}

resource "aws_s3_bucket_public_access_block" "data_lake_public_block" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

locals {
  folders = ["bronze/", "silver/", "gold/"]
}

resource "aws_s3_object" "data_lake_folders" {
  count  = length(local.folders)
  bucket = aws_s3_bucket.data_lake.id
  key    = local.folders[count.index]
}

resource "aws_iam_user" "databricks_user" {
  name = "databricks-ingestion-user"
  path = "/system/"
}

data "aws_iam_policy_document" "s3_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [aws_s3_bucket.data_lake.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.data_lake.arn}/*"]
  }
}

resource "aws_iam_user_policy" "databricks_user_policy" {
  name   = "databricks-s3-access-policy"
  user   = aws_iam_user.databricks_user.name
  policy = data.aws_iam_policy_document.s3_access_policy.json
}

resource "aws_iam_access_key" "databricks_user_key" {
  user = aws_iam_user.databricks_user.name
}

output "s3_bucket_name" {
  description = "Nazwa utworzonego bucketa S3"
  value       = aws_s3_bucket.data_lake.bucket
}

output "iam_access_key_id" {
  description = "AWS Access Key ID dla Databricks"
  value       = aws_iam_access_key.databricks_user_key.id
}

output "iam_secret_access_key" {
  description = "AWS Secret Access Key dla Databricks"
  value       = aws_iam_access_key.databricks_user_key.secret
  sensitive   = true
}