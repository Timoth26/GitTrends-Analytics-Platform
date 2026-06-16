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

# 
resource "aws_glue_catalog_database" "silver_db" {
  name        = "gittrends_silver_db"
  description = "Glue Catalog Database for Silver Layer of GitTrends Data Lake"
}

resource "aws_iam_role" "glue_crawler_role" {
  name = "gittrends-glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_basic" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-access-policy"
  role = aws_iam_role.glue_crawler_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::gittrends-data-lake",
          "arn:aws:s3:::gittrends-data-lake/*"
        ]
      }
    ]
  })
}

resource "aws_glue_crawler" "silver_delta_crawler" {
  name          = "gittrends-silver-crawler"
  database_name = aws_glue_catalog_database.silver_db.name
  role          = aws_iam_role.glue_crawler_role.arn

  delta_target {
    delta_tables   = ["s3://gittrends-data-lake/silver/github_events/"]
    create_native_delta_table = true
    write_manifest = false
  }

  table_prefix = "silver_"

  depends_on = [
    aws_iam_role_policy_attachment.glue_service_basic,
    aws_iam_role_policy.glue_s3_access
  ]
}

# Dedicated S3 bucket for Athena query results to avoid cluttering the main data lake bucket
resource "aws_s3_bucket" "athena_results" {
  bucket = "gittrends-athena-query-results-akkda21"
}

# Automatic cleanup of Athena query results after 7 days to manage storage costs
resource "aws_s3_bucket_lifecycle_configuration" "athena_results_cleanup" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-athena-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 14
    }
  }
}