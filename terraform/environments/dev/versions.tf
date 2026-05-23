terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
  bucket         = "aws-eks-platform-golden-path-dev-tfstate-504441516591"
  key            = "environments/dev/terraform.tfstate"
  region         = "eu-west-3"
  encrypt        = true
  profile        = "tf-eks-golden-path"
  use_lockfile = true
  }
}
