terraform {
  required_version = ">= 0.12"

  backend "s3" {
    bucket = "enoch-tf-state-bucket"
    key    = "stack-S3/terraform.tfstate"
    region = "us-east-1"
  }
} 
