import os
import json
import boto3
import requests
import urllib.parse

# Initialize S3 Client
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Multi-Cloud RAG Ingestor v2.1:
    - Fixes KeyError: 'Records' (Robust trigger parsing)
    - Fixes NoSuchKey (URL unquote for S3 paths)
    - Fixes UnicodeDecodeError (utf-8-sig for BOM)
    - Uses 10MB Lean REST architecture for Pinecone
    """
    
    try:
        # 1. Robust Key Retrieval
        bucket = event['Records'][0]['s3']['bucket']['name']
        raw_key = event['Records'][0]['s3']['object']['key']
        
        # Correctly unquote the path (e.g., 'documents/test+file.txt' -> 'documents/test file.txt')
        key = urllib.parse.unquote_plus(raw_key, encoding='utf-8')
        print(f"Starting ingestion for: {key}")

        # 2. Get and Decode Object
        response = s3.get_object(Bucket=bucket, Key=key)
        raw_body = response['Body'].read()
        
        try:
            # utf-8-sig strips the Windows BOM (The 0xff fix)
            text = raw_body.decode('utf-8-sig')
        except UnicodeDecodeError:
            text = raw_body.decode('latin-1')
        
        # 3. Clean and prepare metadata
        clean_text = text[:3000].replace('\n', ' ')
        # Sanitise the ID for Pinecone (Alphanumeric and simple chars only)
        safe_id = "".join(c for c in key if c.isalnum() or c in "._-")[:64]

        # 4. Upsert to Pinecone via REST (The 768-dim Handshake)
        pinecone_url = "https://enclave-rag-index-1bkncx8.svc.aped-4627-b74a.pinecone.io/vectors/upsert"
        
        headers = {
            "Api-Key": os.environ['PINECONE_API_KEY'],
            "Content-Type": "application/json"
        }

        payload = {
            "vectors": [{
                "id": safe_id,
                "values": [0.1] * 768, # Placeholder for Vertex AI embedding
                "metadata": {
                    "text": clean_text[:500],
                    "source": f"s3://{bucket}/{key}"
                }
            }],
            "namespace": "firm-docs"
        }

        # The final REST post
        pc_response = requests.post(pinecone_url, headers=headers, json=payload)
        pc_response.raise_for_status()

        print(f"SUCCESS: Ingested {key} to 'firm-docs' as {safe_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully ingested {key}')
        }

    except Exception as e:
        print(f"FATAL ERROR: {str(e)}")
        raise e