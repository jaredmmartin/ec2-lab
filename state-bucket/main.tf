############ Local Variables ############

locals {
  name_prefix = "lab"
}

############ Data Sources ############

data "aws_region" "this" {}

data "aws_caller_identity" "this" {}

############ S3 ############

resource "aws_s3_bucket" "this" {
  bucket        = "${local.name_prefix}-tfstate-${data.aws_caller_identity.this.account_id}-${data.aws_region.this.region}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  bucket                  = aws_s3_bucket.this.id
  ignore_public_acls      = true
  restrict_public_buckets = true
}

############ Output ############

output "aws_s3_bucket" {
  value = aws_s3_bucket.this.bucket
}
