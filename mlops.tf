# 1. THE VECTOR DATABASE (PINECONE SERVERLESS)
resource "pinecone_index" "enclave_index" {
  name                = "enclave-rag-index"
  dimension           = 768
  metric              = "cosine"
  deletion_protection = "disabled"

  spec = {
    serverless = {
      cloud  = "aws"
      region = "us-east-1"
    }
  }
}

# 2. THE HEAVY DEPENDENCIES (LAMBDA LAYER)
resource "aws_s3_object" "lambda_layer_zip" {
  bucket = "multi-cloud-rag-state-mm-041826"
  key    = "layers/dependencies.zip"
  source = "dependencies.zip"
  etag   = filemd5("dependencies.zip")
}

resource "aws_lambda_layer_version" "enclave_deps" {
  layer_name         = "enclave-google-pinecone-layer"
  s3_bucket          = aws_s3_object.lambda_layer_zip.bucket
  s3_key             = aws_s3_object.lambda_layer_zip.key
  compatible_runtimes = ["python3.12"]
  compatible_architectures = ["arm64"]
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

  # Upload ONLY the code (very small, no more size errors!)
  filename         = "lambda_code.zip"
  source_code_hash = filebase64sha256("lambda_code.zip")

  # Attach the heavy library layer
  layers = [aws_lambda_layer_version.enclave_deps.arn]

  environment {
    variables = {
      PINECONE_API_KEY        = var.pinecone_api_key
      GCP_PROJECT_ID          = var.gcp_project_id
      GCP_REGION              = "us-central1"
      GOOGLE_CREDENTIALS_JSON = var.google_credentials
    }
  }
}

# 4. IAM PERMISSIONS (RETAINED)
resource "aws_iam_role" "lambda_exec" {
  name = "enclave_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
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
        Action   = ["s3:GetObject"]
        Effect   = "Allow"
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

# 5. THE S3 TRIGGER (RETAINED)
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