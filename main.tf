data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-${var.RUNNER}-${var.ORGANIZATION}-${var.bucket_usage}-bucket"
  tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-bucket"
    Purpose     = "${var.bucket_usage}"
  }
  object_lock_enabled = true
  force_destroy = true
}

resource "aws_s3_bucket" "logging" {
  bucket = "tf-${var.RUNNER}-${var.ORGANIZATION}-logging-bucket"
    tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-logging-bucket"
    Purpose     = "logging"
  }
  force_destroy = true
}
