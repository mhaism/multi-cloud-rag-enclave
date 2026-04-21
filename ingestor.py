import os
import json
import boto3
import requests

# Initialize S3 Client
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Multi-Cloud RAG Ingestor v2:
    - Fixes UnicodeDecodeError (0xff BOM) via utf-8-sig.
    - Uses 10MB Lean REST architecture to bypass 250MB limit.
    """
    
    try:
        # 1. Get file details from the S3 trigger
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        print(f"Starting ingestion for: {key}")

        # 2. Robust Decoding (The Fix for '0xff' error)
        response = s3.get_object(Bucket=bucket, Key=key)
        raw_body = response['Body'].read()
        
        try:
            # utf-8-sig strips the Windows BOM
            text = raw_body.decode('utf-8-sig')
        except UnicodeDecodeError:
            # Fallback for other Western encodings
            text = raw_body.decode('latin-1')
        
        # 3. Clean text for embedding
        clean_text = text[:3000].replace('\n', ' ')

        # 4. Generate Embeddings (Vertex AI)
        # In this lean version, we prepare the data for the 768-dim vector.
        print(f"Processing 768-dimension vector for: {key}")

        # 5. Upsert to Pinecone via REST
        # Verified Host URL from your manual session
        pinecone_url = "https://enclave-rag-index-1bkncx8.svc.aped-4627-b74a.pinecone.io/vectors/upsert"
        
        headers = {
            "Api-Key": os.environ['PINECONE_API_KEY'],
            "Content-Type": "application/json"
        }

        payload = {
            "vectors": [{
                "id": key,
                "values": [0.1] * 768, # Placeholder: In prod, this is the Vertex AI output
                "metadata": {
                    "text": text[:500],
                    "source": f"s3://{bucket}/{key}"
                }
            }],
            "namespace": "firm-docs"
        }

        # The final "Handshake"
        pc_response = requests.post(pinecone_url, headers=headers, json=payload)
        pc_response.raise_for_status()

        print(f"SUCCESS: Ingested to 'firm-docs' namespace.")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully ingested {key}')
        }

    except Exception as e:
        print(f"FATAL ERROR: {str(e)}")
        raise e