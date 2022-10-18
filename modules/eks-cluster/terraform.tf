terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
      #configuration_aliases = [aws.someAlias] 
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
}