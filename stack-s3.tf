resource "aws_s3_bucket" "bucket" {
  bucket    = "tf-${var.AWS_REGION}-${var.RUNNER}-${var.ORGANIZATION}-s3-bucket"
  tags      = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-bucket"
    ManagedBy   = "${var.ManagedBy}"
    Environment = "${var.ENVIRONMENT}"
  }
  force_destroy = true
}