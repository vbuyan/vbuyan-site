terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # bucket is passed at init: -backend-config="bucket=vbuyan-tfstate-<account>"
  backend "s3" {
    key          = "vbuyan-site/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  # CloudFront certificates must live in us-east-1, so everything does.
  region = "us-east-1"

  default_tags {
    tags = {
      project    = "vbuyan-site"
      managed-by = "terraform"
      repo       = "github.com/vbuyan/vbuyan-site"
    }
  }
}
