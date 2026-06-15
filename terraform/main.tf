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
  description = "S3 bucket's name"
  value       = aws_s3_bucket.data_lake.bucket
}

output "iam_access_key_id" {
  description = "AWS Access Key ID for Databricks"
  value       = aws_iam_access_key.databricks_user_key.id
}

output "iam_secret_access_key" {
  description = "AWS Secret Access Key for Databricks"
  value       = aws_iam_access_key.databricks_user_key.secret
  sensitive   = true
}

# Potential changes in the AWS Console following the Databricks permissions update
resource "aws_iam_role" "s3_read_only_role" {
  name = "s3-read-only-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "databricks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_read_only_policy" {
  name = "s3-read-only-policy"
  role = aws_iam_role.s3_read_only_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = ["arn:aws:s3:::gittrends-data-lake"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = ["arn:aws:s3:::gittrends-data-lake/*"]
      }
    ]
  })
}

output "s3_read_only_role_arn" {
  description = "ARN of the S3 read-only IAM role for Databricks"
  value       = aws_iam_role.s3_read_only_role.arn
}