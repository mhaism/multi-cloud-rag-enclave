# backend-setup.tf

# 1. The Secure S3 Bucket
resource "aws_s3_bucket" "terraform_state" {
  # Replace 'your-unique-alias' with something globally unique (e.g., your initials and date)
  bucket = "multi-cloud-rag-state-your-unique-alias"

  # Prevents accidental deletion of this critical bucket
  lifecycle {
    prevent_destroy = true
  }
}

# 2. Enable Versioning (Crucial for rolling back state corruption)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. Force Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4. Block ALL Public Access (Zero Trust baseline)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 5. The DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "multi-cloud-rag-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}