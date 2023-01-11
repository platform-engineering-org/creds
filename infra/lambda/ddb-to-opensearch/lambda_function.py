import os

import boto3
import requests
from requests_aws4auth import AWS4Auth

region = os.getenv("AWS_REGION")
service = "es"
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    service,
    session_token=credentials.token,
)

host = os.getenv("host")
index = "lambda-index"
datatype = "_doc"
url = host + "/" + index + "/" + datatype + "/"

headers = {"Content-Type": "application/json"}


def lambda_handler(event, context):
    count = 0
    for record in event["Records"]:
        id = record["dynamodb"]["Keys"]["id"]["S"]

        document = record["dynamodb"]["NewImage"]
        r = requests.put(
            url + id, auth=awsauth, json=document, headers=headers
        )
        print(r)
        count += 1
    return str(count) + " records processed."
