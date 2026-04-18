import os
import json
import boto3
from pinecone import Pinecone

# 1. Initialize Clients
# We use the standard Pinecone client for the Free Tier
pc = Pinecone(api_key=os.environ['PINECONE_API_KEY'])
index = pc.Index("enclave-rag-index")
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Triggered by S3 when a .txt file is uploaded to the 'documents/' folder.
    """
    try:
        # 2. Extract Bucket and File info from the S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        
        print(f"Processing file: {key} from bucket: {bucket}")

        # 3. Fetch the content from S3
        response = s3.get_object(Bucket=bucket, Key=key)
        document_text = response['Body'].read().decode('utf-8')

        # 4. Placeholder for Embedding Logic 
        # For the first 'Green' push, we use a dummy vector to verify the plumbing.
        # This prevents the 50MB zip limit error during initial deployment.
        dummy_vector = [0.1] * 384 

        # 5. Upsert to Pinecone
        # We store the original text in metadata so we can retrieve it later.
        index.upsert(
            vectors=[
                {
                    "id": key, 
                    "values": dummy_vector, 
                    "metadata": {
                        "text": document_text[:1000], # Store first 1000 chars
                        "source": f"s3://{bucket}/{key}"
                    }
                }
            ],
            namespace="firm-docs"
        )

        return {
            'statusCode': 200,
            'body': json.dumps(f"Successfully indexed {key}")
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps("Error processing document")
        }