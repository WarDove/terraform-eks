terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
    }

    utils = {
      source  = "cloudposse/utils"
      version = "~> 1.5"
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
