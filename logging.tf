resource "aws_s3_bucket_logging" "bucket" {
  bucket        = aws_s3_bucket.bucket.bucket
  target_bucket = aws_s3_bucket.logging.bucket
  target_prefix = "log/"
  target_object_key_format {
    partitioned_prefix {
      partition_date_source = "EventTime"
    }
  }
}
