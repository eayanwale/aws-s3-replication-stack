variable "ACCOUNT_ID" {
  type = string
}

variable "REPLICA_ACCOUNT_ID" {
  type = string
}

variable "AWS_REGION" {
  default = "us-east-1"
}

variable "REPLICA_ROLE_NAME" {
  default = "Engineer"
}

variable "bucket_usage" {
  type = string
  default = "general"
}

variable "ENVIRONMENT" {
  default = "Development"
}

variable "ROLE_NAME" {
  type = string
}

variable "RUNNER" {
  type = string
}

variable "ManagedBy" {
  default = "terraform"
}

variable "ORGANIZATION" {
  type = string
}

