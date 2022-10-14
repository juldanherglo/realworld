terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.7"
    }
  }
}

provider "aws" {
  profile = "takehome"
  region  = "eu-west-1"
}
