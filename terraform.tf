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
      version = "= 2.5.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.14"
    }
  }

  required_version = ">=1.2.8"

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

# Pre-requisite: kubectl-v1.24.2
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  host                   = module.eks-cluster.kube-api-endpoint
  token                  = module.eks-cluster.kube-api-token
  cluster_ca_certificate = base64decode(module.eks-cluster.kubeconfig-certificate-authority-data)
}