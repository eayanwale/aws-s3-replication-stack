resource "aws_kms_key" "bucket_key" {
  description               = "KMS key for S3 bucket encryption"
  deletion_window_in_days   = 10
  enable_key_rotation       = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_kms_alias" "bucket_key_alias" {
  name          = "alias/${var.RUNNER}-${var.ORGANIZATION}-bucket-key"
  target_key_id = aws_kms_key.bucket_key.id
}