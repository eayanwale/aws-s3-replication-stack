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

resource "aws_s3_bucket_public_access_block" "region_replication_public_access" {
  provider = aws.us-east-2
  bucket   = aws_s3_bucket.region_replication_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
