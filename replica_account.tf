resource "aws_s3_bucket" "account_replication_bucket" {
  provider = aws.test-account
  bucket   = "tf-replica-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-${var.REPLICA_ACCOUNT_ID}"
  tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-replication-bucket"
    Purpose     = "S3 account replication destination bucket"
  }
  object_lock_enabled = true
  force_destroy       = true
}

resource "aws_s3_bucket_versioning" "account_replication_versioning" {
  provider = aws.test-account
  bucket   = aws_s3_bucket.account_replication_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "account_replication_encryption" {
  provider = aws.test-account
  bucket   = aws_s3_bucket.account_replication_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "account_replication_public_access" {
  provider = aws.test-account
  bucket   = aws_s3_bucket.account_replication_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "account_replication_policy" {
  provider = aws.test-account
  bucket   = aws_s3_bucket.account_replication_bucket.id

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
        Resource = ["${aws_s3_bucket.account_replication_bucket.arn}/*"]
      },
      {
        Sid       = "AllowSourceReplicationRoleListVersioning"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replication_role.arn }
        Action    = [
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource  = [aws_s3_bucket.account_replication_bucket.arn]
      }
    ]
  })
}
