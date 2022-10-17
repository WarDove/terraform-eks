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

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.7"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.14"
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

# Providers
provider "aws" {
  profile = var.profile
  region  = var.region
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  #config_context = "default"
}