provider "aws" {
  region = var.AWS_REGION

  assume_role {
    role_arn = "arn:aws:iam::${var.ACCOUNT_ID}:role/${var.ROLE_NAME}"
  }
}
