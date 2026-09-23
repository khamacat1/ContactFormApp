data "aws_caller_identity" "current" {}

# S3 bucket names are globally unique across ALL of AWS, not just this
# account — suffixing with the account id avoids collisions with other
# AWS customers without needing a random suffix.
locals {
  state_bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
  lock_table_name    = "${var.project_name}-tfstate-lock"
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_bucket_name

  # Safety net: `terraform destroy` on this bootstrap config will refuse
  # to delete the bucket while it still holds the state files that every
  # other Terraform config in this project depends on.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypts state at rest — state files can contain sensitive values
# (e.g. generated passwords, resource ARNs) depending on what later
# Terraform configs provision.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Locking prevents two `terraform apply` runs from writing to the same
# state concurrently and corrupting it.
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
