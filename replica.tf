
resource "aws_kms_key" "replica_key" {
  provider                = aws.us-east-2
  description             = "KMS key for S3 bucket replication"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "replica" {
  provider = aws.us-east-2
  bucket   = "tf-${var.AWS_REGION}-replication-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-bucket"
  tags     = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-replication-bucket"
    ManagedBy   = "${var.ManagedBy}"
    Environment = "${var.ENVIRONMENT}"
  }
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_encryption" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.replica.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.replica_key.id
    }
  }
}

resource "aws_s3_bucket_public_access_block" "replica_public_access" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.replica.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_iam_role" "replica_role" {
  name = "${var.ORGANIZATION}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "replica" {
  name = "${var.ORGANIZATION}-s3-replication-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSourceBucketRead"
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.bucket.arn]
      },
      {
        Sid    = "AllowSourceObjectRead"
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${aws_s3_bucket.bucket.arn}/*"]
      },
      {
        Sid    = "AllowReplicaWrite"
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = ["${aws_s3_bucket.replica.arn}/*"]
      },
      {
        Sid      = "AllowSourceKMSDecrypt"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [aws_kms_key.bucket_key.arn]
      },
      {
        Sid      = "AllowReplicaKMSEncrypt"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = [aws_kms_key.replica_key.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication_attachment" {
  role       = aws_iam_role.replica_role.name
  policy_arn = aws_iam_policy.replica.arn
}

resource "aws_s3_bucket_replication_configuration" "replication_config" {
  depends_on = [aws_iam_role_policy_attachment.replication_attachment]
  
  bucket = aws_s3_bucket.bucket.id
  role = aws_iam_role.replica_role.arn

  rule {
    id     = "replication-rule-1"
    status = "Enabled"

    filter {}

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
      access_control_translation {
        owner = "Destination"
      }
    }
  }
}