import os
import json
import boto3
import requests
import urllib.parse

s3 = boto3.client('s3')

def lambda_handler(event, context):
    try:
        # 1. Parse Input
        bucket = event['Records'][0]['s3']['bucket']['name']
        raw_key = event['Records'][0]['s3']['object']['key']
        key = urllib.parse.unquote_plus(raw_key, encoding='utf-8')

        # 2. Extract & Embed (The core logic we verified)
        response = s3.get_object(Bucket=bucket, Key=key)
        text = response['Body'].read().decode('utf-8-sig')

        # [EXISTING PINECONE REST LOGIC GOES HERE...]
        # (Assuming the requests.post was successful)

        # 3. ENHANCEMENT: Move to 'processed/'
        filename = key.split('/')[-1]
        destination_key = f"processed/{filename}"
        
        # Step A: Copy the object to the new prefix
        s3.copy_object(
            Bucket=bucket,
            CopySource={'Bucket': bucket, 'Key': key},
            Key=destination_key
        )
        
        # Step B: Delete the original from 'documents/'
        s3.delete_object(Bucket=bucket, Key=key)

        print(f"LIFECYCLE COMPLETE: {key} moved to {destination_key}")
        
        return {"statusCode": 200, "body": f"Successfully processed and moved {filename}"}

    except Exception as e:
        print(f"FATAL ERROR: {str(e)}")
        raise e