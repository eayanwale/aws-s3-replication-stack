resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "tf-${var.RUNNER}-${var.ORGANIZATION}-cloudtrail-logs"
    tags = {
    Name        = "${var.ManagedBy}-${var.ORGANIZATION}-cloudtrail-logs-bucket"
    Purpose     = "cloudtrail-logs"
  }
  force_destroy = true
}

data "aws_iam_policy_document" "cloudtrail_bucket_policy" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket_policy.json
}

resource "aws_cloudtrail" "s3_data_events" {
  name                       = "s3-object-level-trail"
  s3_bucket_name             = aws_s3_bucket.cloudtrail_logs.id
  enable_log_file_validation = true
  is_multi_region_trail = true

  advanced_event_selector {
    name = "Log S3 object-level data events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field  = "eventName"
      equals = ["GetObject", "PutObject", "DeleteObject"]
    }

    field_selector {
      field       = "resources.ARN"
      starts_with = ["${aws_s3_bucket.bucket.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}