data "aws_iam_policy_document" "main_bucket_policy" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
  }

  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.REPLICA_ACCOUNT_ID}:root"]
    }
    actions   = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
  }
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.REPLICA_ACCOUNT_ID}:role/${var.REPLICA_ROLE_NAME}"]
    }
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags", "s3:ObjectOwnerOverrideToBucketOwner"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "main_bucket_policy" {
  bucket     = aws_s3_bucket.bucket.id
  policy     = data.aws_iam_policy_document.main_bucket_policy.json
  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

data "aws_iam_policy_document" "logging_bucket_policy" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logging.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "logging_bucket_policy" {
  bucket = aws_s3_bucket.logging.id
  policy = data.aws_iam_policy_document.logging_bucket_policy.json
}
