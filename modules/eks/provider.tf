terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.25"
      #configuration_aliases = [aws.someAlias] 
    }
  }
}