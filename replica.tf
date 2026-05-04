
resource "aws_kms_key" "replica_key" {
  provider                = aws.us-east-2
  description             = "KMS key for S3 bucket replication"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket" "replica" {
  provider = aws.us-east-2
  bucket   = "tf-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-replica"
  tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-replication-bucket"
    Purpose     = "S3 replication destination bucket"
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
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "replica" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.replica.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.replica_role.arn }
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.replica.arn,
          "${aws_s3_bucket.replica.arn}/*"
        ]
      }
    ]
  })
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
          "s3:ReplicateTags",
          "s3:ObjectOwnerOverrideToBucketOwner"
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
  depends_on = [aws_s3_bucket_versioning.versioning, aws_s3_bucket_versioning.replica_versioning]

  bucket = aws_s3_bucket.bucket.id
  role   = aws_iam_role.replica_role.arn

  rule {
    id     = "replication-rule-1"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
      account       = var.REPLICA_ACCOUNT_ID

      access_control_translation {
        owner = "Destination"
      }

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.replica_key.arn
      }
    }

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }
  }
}
