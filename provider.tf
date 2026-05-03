provider "aws" {
  region = var.AWS_REGION

  assume_role {
    role_arn = "arn:aws:iam::${var.ACCOUNT_ID}:role/${var.ROLE_NAME}"
  }
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"

  assume_role {
    role_arn = "arn:aws:iam::${var.REPLICA_ACCOUNT_ID}:role/${var.REPLICA_ROLE_NAME}"
  }
}