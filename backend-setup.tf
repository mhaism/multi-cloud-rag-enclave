# backend-setup.tf

# 1. The Secure S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
  # checkov:skip=CKV_AWS_144: Cross-region replication is overkill for this lab's state file
  # checkov:skip=CKV_AWS_18: Access logging is overkill for this lab's state file
  # checkov:skip=CKV_AWS_145: AES256 server-side encryption is sufficient; dedicated KMS key is overkill
  # checkov:skip=CKV2_AWS_62: Event notifications are not required for terraform state
  # checkov:skip=CKV2_AWS_61: Lifecycle data expiration is not required; state must persist

  # REPLACE THIS with your globally unique name
  bucket = "multi-cloud-rag-state-mm-041826"

  lifecycle {
    prevent_destroy = true
  }
}

# 2. Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Force Server-Side Encryption (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Block ALL Public Access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. The DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  # checkov:skip=CKV_AWS_119: Default AWS-owned encryption is sufficient; Customer Managed Key is overkill
  name         = "multi-cloud-rag-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}