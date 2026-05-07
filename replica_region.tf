
resource "aws_kms_key" "region_replication_key" {
  provider                = aws.us-east-2
  description             = "KMS key for S3 bucket replication"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key_policy" "region_replication_key" {
  provider = aws.us-east-2
  key_id   = aws_kms_key.region_replication_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.ACCOUNT_ID}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowSourceReplicationRoleEncrypt"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replication_role.arn }
        Action = [
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:ReEncrypt*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "region_replication_bucket" {
  provider = aws.us-east-2
  bucket   = "tf-replica-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-us-east-2"
  tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-replication-bucket"
    Purpose     = "S3 region replication destination bucket"
  }
  object_lock_enabled = true
  force_destroy       = true
}

resource "aws_s3_bucket_versioning" "region_replication_versioning" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.region_replication_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "region_replication_encryption" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.region_replication_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.region_replication_key.id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "region_replication_public_access" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.region_replication_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "region_replication_policy" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.region_replication_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSourceReplicationRoleWrite"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replication_role.arn }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
        ]
        Resource = ["${aws_s3_bucket.region_replication_bucket.arn}/*"]
      },
      {
        Sid       = "AllowSourceReplicationRoleListVersioning"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replication_role.arn }
        Action    = [
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource  = [aws_s3_bucket.region_replication_bucket.arn]
      }
    ]
  })
}