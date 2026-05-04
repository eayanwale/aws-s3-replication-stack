locals {
  static_objects = {
    "static/app-config.json"    = "application/json"
    "static/reference.csv"      = "text/csv"
  }
  public_objects = {
    "index.html" = "text/html"
    "error.html" = "text/html"
  }
}

resource "aws_s3_object" "public" {
  for_each     = local.public_objects
  bucket       = aws_s3_bucket.bucket.id
  key          = each.key
  source       = "${path.module}/assets/public/${each.key}"
  content_type = each.value
  source_hash  = filemd5("${path.module}/assets/public/${each.key}")
}

resource "aws_s3_object" "static" {
  for_each     = local.static_objects
  bucket       = aws_s3_bucket.bucket.id
  key          = each.key
  source       = "${path.module}/assets/${each.key}"
  content_type = each.value
  source_hash  = filemd5("${path.module}/assets/${each.key}")
  #etag = filemd5("${path.module}/assets/index.html")
  # ETAG uses MD5 hash. Cannot be used here as our buxkets, and objects are KMS encrypted
    # KMS does not use MD5 hash so ETAG here is useless
}