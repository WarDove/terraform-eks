terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
    }
  }

  required_version = ">= 0.14.9"

  backend "s3" {
    bucket         = "gitlab-poc-terraform-eu-central-1"
    encrypt        = "true"
    key            = "---insert-key-here"
    dynamodb_table = "gitlab-poc-terraform-locks"
    region         = "eu-central-1"
  }
}

provider "aws" {
  profile = var.profile
  region  = "eu-west-1"
}

# provider "aws" {
#   profile = var.profile
#   region  = "us-east-2"
#   alias   = "route53"
# }