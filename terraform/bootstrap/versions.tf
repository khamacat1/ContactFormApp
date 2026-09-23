terraform {
  required_version = ">= 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Deliberately local state for this bootstrap config only — it creates
  # the S3 bucket + DynamoDB table that every OTHER Terraform config in
  # this project uses as its remote backend. Bootstrapping the bootstrap
  # would be circular. This config is small, applied once, and rarely
  # touched again.
}

provider "aws" {
  region = var.aws_region
}
