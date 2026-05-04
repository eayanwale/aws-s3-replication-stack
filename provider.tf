provider "aws" {
  region = var.AWS_REGION

  assume_role {
    role_arn = "arn:aws:iam::${var.ACCOUNT_ID}:role/${var.ROLE_NAME}"
  }

  default_tags {
    tags = {
      Name        = "${var.ManagedBy}-${var.ORGANIZATION}-s3-bucket"
      Role        = "${var.ROLE_NAME}"
      ManagedBy   = "${var.ManagedBy}"
      Environment = "${var.ENVIRONMENT}"
      CreatedBy   = "${var.RUNNER}"
      Purpose     = "${var.bucket_usage}"
      Organization = "${var.ORGANIZATION}"
    }
  }
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  assume_role {
    role_arn = "arn:aws:iam::${var.REPLICA_ACCOUNT_ID}:role/${var.REPLICA_ROLE_NAME}"
  }

  default_tags {
    tags = {
      ManagedBy   = "${var.ManagedBy}"
      Environment = "${var.ENVIRONMENT}"
      CreatedBy   = "${var.RUNNER}"
      Organization = "${var.ORGANIZATION}"
    }
  }
}