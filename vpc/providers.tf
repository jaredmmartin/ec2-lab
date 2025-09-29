terraform {
  backend "s3" {
    bucket = "lab-tfstate-875568359137-us-west-2"
    key    = "vpc/tfstate"
    region = "us-west-2"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}
