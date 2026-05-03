data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-${var.ROLE_NAME}-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-bucket"
  tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-bucket"
    ManagedBy   = "${var.ManagedBy}"
    Environment = "${var.ENVIRONMENT}"
  }
  force_destroy = true
}

resource "aws_s3_bucket" "logging" {
  bucket = "access-logging-bucket"
}

resource "aws_s3_bucket" "notification_bucket" {
  bucket = "your-bucket-name"
}
