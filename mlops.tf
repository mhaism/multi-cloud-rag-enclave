# 1. THE VECTOR DATABASE (PINECONE SERVERLESS)
resource "pinecone_index" "enclave_index" {
  name                = "enclave-rag-index"
  dimension           = 768 # Matches Vertex AI text-embedding-004
  metric              = "cosine"
  deletion_protection = "disabled"

  spec = {
    serverless = {
      cloud  = "aws"
      region = "us-east-1"
    }
  }
}

# 2. THE DEPLOYMENT PACKAGE (S3 SIDE-LOAD)
# This resource handles the large file upload to bypass the 70MB API limit.
resource "aws_s3_object" "lambda_package" {
  bucket = "multi-cloud-rag-state-mm-041826"
  key    = "deployments/lambda_function.zip"
  source = "lambda_function.zip"
  # This triggers an update only when the file content actually changes
  etag = filemd5("lambda_function.zip")
}

# 3. THE AI WORKER (AWS LAMBDA)
resource "aws_lambda_function" "ingestor" {
  function_name = "enclave-document-ingestor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "ingestor.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  timeout       = 30
  memory_size   = 512

  # Pointing to the S3 Object instead of a local filename to handle the large size
  s3_bucket        = aws_s3_object.lambda_package.bucket
  s3_key           = aws_s3_object.lambda_package.key
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      PINECONE_API_KEY        = var.pinecone_api_key
      GCP_PROJECT_ID          = var.gcp_project_id
      GCP_REGION              = "us-central1"
      GOOGLE_CREDENTIALS_JSON = var.google_credentials
    }
  }
}

# 4. IAM PERMISSIONS
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

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "enclave_lambda_s3_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = ["s3:GetObject"]
        Effect = "Allow"
        # Corrected Resource syntax
        Resource = ["arn:aws:s3:::multi-cloud-rag-state-mm-041826/*"]
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# 5. THE S3 TRIGGER
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

output "pinecone_api_key" {
  value     = var.pinecone_api_key
  sensitive = true
}