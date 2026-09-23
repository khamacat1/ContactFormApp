terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Values intentionally hardcoded, not variables — Terraform backend
    # blocks cannot reference variables/locals (they're needed before any
    # configuration is evaluated). Must match the bootstrap config's outputs.
    bucket         = "contactform-tfstate-878585013555"
    key            = "contactform/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "contactform-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
