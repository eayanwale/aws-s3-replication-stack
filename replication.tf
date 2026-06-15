resource "aws_iam_role" "replication_role" {
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

resource "aws_iam_policy" "replication_policy" {
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
          "s3:GetObjectVersionTagging",
          "s3:GetObjectRetention",
          "s3:GetObjectLegalHold"
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
        Resource = [
          "${aws_s3_bucket.region_replication_bucket.arn}/*",
          "${aws_s3_bucket.account_replication_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication_attachment" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

resource "aws_s3_bucket_replication_configuration" "replication_config" {
  bucket = aws_s3_bucket.bucket.id
  role   = aws_iam_role.replication_role.arn

  depends_on = [
    aws_s3_bucket_versioning.versioning,
    aws_s3_bucket_versioning.region_replication_versioning,
    aws_s3_bucket_versioning.account_replication_versioning,
  ]

  rule {
    id       = "replication-rule-1"
    priority = 1
    status   = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.region_replication_bucket.arn
      storage_class = "STANDARD"
    }
  }

  rule {
    id       = "replication-rule-2"
    priority = 2
    status   = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.account_replication_bucket.arn
      storage_class = "STANDARD"
      account       = var.REPLICA_ACCOUNT_ID

      access_control_translation {
        owner = "Destination"
      }
    }
  }
}
