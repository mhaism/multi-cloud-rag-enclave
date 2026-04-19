@'
import os
import json
import boto3
from pinecone import Pinecone

# The "Brain" connection
pc = Pinecone(api_key=os.environ['PINECONE_API_KEY'])
index = pc.Index("enclave-rag-index")
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get file details from the S3 trigger
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    # Read the document from S3
    response = s3.get_object(Bucket=bucket, Key=key)
    text = response['Body'].read().decode('utf-8')
    
    # Store in Pinecone (using dummy vectors for the lab)
    index.upsert(
        vectors=[{
            "id": key, 
            "values": [0.1] * 384, 
            "metadata": {"text": text[:1000]}
        }], 
        namespace="firm-docs"
    )
    
    print(f"Successfully ingested: {key}")
    return {'statusCode': 200, 'body': json.dumps('Ingestion Complete')}
'@ | Out-File -FilePath ingestor.py -Encoding utf8# Force update 04/20/2026 09:29:02
