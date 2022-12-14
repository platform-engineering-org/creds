#!/usr/bin/env python3

import boto3
import gzip
import json
import os
import pathlib
import shutil

BUCKET_NAME = 'tf-creds-trail'
DOWNLOAD_PATH = 'AWSLogs/203972369401/CloudTrail/eu-west-2/2022/12/13/'


def download_items(bucket_name: str, download_path: pathlib.Path) -> None:
    """Prints to console the content of all json files are fount at download_path

    Params:
        bucket_name (str): The name of the bucket
        download_path (pathlib.Path): The path in the bucket we want to get the content of the json files from

    Returns:
        None

    """
    s3 = boto3.resource('s3')
    s3_client = boto3.client('s3')
    bucket = s3.Bucket(bucket_name)
    my_bucket = s3_client.list_objects(
        Bucket=bucket_name, Marker=download_path)['Contents']

    for s3_object in my_bucket:
        object_key = s3_object['Key']
        file_name = os.path.basename(object_key)

        with open(file_name, '+wb') as f:
            bucket.download_fileobj(object_key, f)

        with gzip.open(file_name, "rb") as f:
            data = json.loads(f.read().decode("ascii"))

            for _, list in data.items():
                for value in list:
                    if value["userIdentity"]["type"] == 'AssumedRole':
                        print('role')
                        break
                    if value["userIdentity"]["type"] == 'IAMUser':
                        print('creds')
                        break

        os.remove(file_name)


def main():
    download_items(BUCKET_NAME, DOWNLOAD_PATH)


if __name__ == "__main__":
    main()
