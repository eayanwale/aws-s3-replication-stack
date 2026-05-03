resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "index.html"
  source       = "${path.module}/assets/index.html"
  content_type = "text/html"
  kms_key_id   = aws_kms_key.bucket_key.arn
  metadata     = { environment = var.ENVIRONMENT }
  etag         = filemd5("${path.module}/assets/index.html")
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "error.html"
  source       = "${path.module}/assets/error.html"
  content_type = "text/html"
  kms_key_id   = aws_kms_key.bucket_key.arn
  metadata     = { environment = var.ENVIRONMENT }
  etag         = filemd5("${path.module}/assets/error.html")
}

resource "aws_s3_object" "config" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "config/app-config.json"
  source       = "${path.module}/assets/app-config.json"
  content_type = "application/json"
  kms_key_id   = aws_kms_key.bucket_key.arn
  metadata     = { environment = var.ENVIRONMENT }
  etag         = filemd5("${path.module}/assets/app-config.json")
}

resource "aws_s3_object" "reference_data" {
  bucket       = aws_s3_bucket.bucket.id
  key          = "data/reference.csv"
  source       = "${path.module}/assets/reference.csv"
  content_type = "text/csv"
  kms_key_id   = aws_kms_key.bucket_key.arn
  metadata     = { environment = var.ENVIRONMENT }
  etag         = filemd5("${path.module}/assets/reference.csv")
}
