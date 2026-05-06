resource "aws_kms_key" "bucket_key" {
  description               = "KMS key for S3 bucket encryption"
  deletion_window_in_days   = 10
  enable_key_rotation       = true
}

resource "aws_kms_key_policy" "bucket_key" {
  key_id = aws_kms_key.bucket_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableRootAccountAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.ACCOUNT_ID}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowReplicationRoleDecrypt"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replica_role.arn }
        Action    = ["kms:Decrypt", "kms:DescribeKey"]
        Resource  = "*"
      }
    ]
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bucket_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_kms_alias" "bucket_key_alias" {
  name          = "alias/${var.RUNNER}-${var.ORGANIZATION}-bucket-key"
  target_key_id = aws_kms_key.bucket_key.id
}