import os
import json
import boto3
from pinecone import Pinecone
from google.cloud import aiplatform
from google.oauth2 import service_account
from vertexai.language_models import TextEmbeddingModel

# 1. Multi-Cloud Authentication (AWS to GCP)
def get_gcp_client():
    try:
        # Parse the JSON string from Environment Variables
        gcp_json = json.loads(os.environ['GOOGLE_CREDENTIALS_JSON'])
        creds = service_account.Credentials.from_service_account_info(gcp_json)
        
        # Initialize Vertex AI
        aiplatform.init(
            project=os.environ['GCP_PROJECT_ID'], 
            location=os.environ['GCP_REGION'], 
            credentials=creds
        )
        return TextEmbeddingModel.from_pretrained("text-embedding-004")
    except Exception as e:
        print(f"Failed to initialize GCP: {e}")
        raise

# Initialize Clients
s3 = boto3.client('s3')
pc = Pinecone(api_key=os.environ['PINECONE_API_KEY'])
index = pc.Index("enclave-rag-index")
embedding_model = get_gcp_client()

def lambda_handler(event, context):
    # Get file details from the S3 trigger
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    print(f"Starting ingestion for: {key}")
    
    # Read the document from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    text = response['Body'].read().decode('utf-8')
    
    # 2. Generate Real Semantic Embeddings via Vertex AI
    # We take the first 3000 chars to stay within common model limits
    clean_text = text[:3000].replace('\n', ' ')
    embeddings = embedding_model.get_embeddings([clean_text])
    vector_values = embeddings[0].values
    
    # 3. Store in Pinecone
    index.upsert(
        vectors=[{
            "id": key, 
            "values": vector_values, 
            "metadata": {
                "text": text[:1000],
                "source": f"s3://{bucket}/{key}",
                "cloud": "multi-cloud-enclave"
            }
        }], 
        namespace="firm-docs"
    )
    
    print(f"Successfully ingested semantic vector for: {key}")
    return {'statusCode': 200, 'body': json.dumps('Multi-Cloud Ingestion Complete')}