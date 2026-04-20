# 1. THE VECTOR DATABASE (PINECONE SERVERLESS)
# Using the 2026 Free Tier spec for zero hourly cost
resource "pinecone_index" "enclave_index" {
  name                = "enclave-rag-index"
  dimension           = 384      # Matches all-MiniLM-L6-v2
  metric              = "cosine" # Best for semantic similarity
  deletion_protection = "disabled"

  spec = {
    serverless = {
      cloud  = "aws"
      region = "us-east-1" # The primary 2026 free-tier region
    }
  }
}

# 2. THE AI WORKER (AWS LAMBDA)
resource "aws_lambda_function" "ingestor" {
  filename         = "lambda_function.zip"
  function_name    = "enclave-document-ingestor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "ingestor.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  timeout          = 30
  memory_size      = 512
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      PINECONE_API_KEY = var.pinecone_api_key
    }
  }
}

# 4. IAM PERMISSIONS (THE SECURITY GUARD)
resource "aws_iam_role" "lambda_exec" {
  name = "enclave_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Allow Lambda to read from your S3 bucket
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "enclave_lambda_s3_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
        Resource = ["arn:aws:s3:::multi-cloud-rag-state-mm-041826/documents/*"]
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 5. THE S3 TRIGGER (THE "ALARM CLOCK")
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::multi-cloud-rag-state-mm-041826"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "multi-cloud-rag-state-mm-041826"

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingestor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".txt"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}