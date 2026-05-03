variable "ACCOUNT_ID" {
  default = "222222222222"
}

variable "AWS_REGION" {
  default = "us-east-1"
}

variable "bucket_usage" {
  type = string
}

variable "ENVIRONMENT" {
  default = "Development"
}

variable "ROLE_NAME" {
  default = "Engineer"
}

variable "RUNNER" {
  default = "enoch"
}

variable "ManagedBy" {
  default = "terraform"
}

variable "ORGANIZATION" {
  default = "stackit"
}

variable "PATH_TO_PRIVATE_KEY" {
  default = "mykey"
}

variable "PATH_TO_PUBLIC_KEY" {
  default = "mykey.pub"
}

variable "AMIS" {
  type = map(string)
  default = {
    us-east-1 = "ami-08f3d892de259504d"
    us-west-2 = "ami-06b94666"
    eu-west-1 = "ami-844e0bf7"
  }
}
