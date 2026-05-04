# outputs.tf

# Main bucket — primary consumer interface
output "bucket_id" {
  description = "Name of the main S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  description = "ARN of the main S3 bucket — use to grant IAM access"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name — use as a CloudFront origin"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the main bucket"
  value       = aws_kms_key.bucket_key.arn
}

output "logging_bucket_id" {
  description = "Name of the access logging bucket"
  value       = aws_s3_bucket.logging.id
}

output "cloudtrail_logs_bucket_id" {
  description = "Name of the CloudTrail logs bucket"
  value       = aws_s3_bucket.cloudtrail_logs.id
}

output "website_endpoint" {
  description = "Static website endpoint URL"
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}