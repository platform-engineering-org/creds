from datetime import date, timedelta

import boto3


def lambda_handler(event, context):
    """Lambda Handler"""

    today = date.today()
    yesterday = today - timedelta(days=1)

    client = boto3.client("cloudtrail")
    eds_id = event["eds-arn"].replace('"', "").split("/")[1]

    query = (
        "SELECT userIdentity.arn AS Name, eventName "
        f"FROM {eds_id} "
        f"WHERE userIdentity.type='IAMUser' "
        f"AND eventTime > '{yesterday} 00:00:00' "
        f"AND eventTime < '{today} 00:00:00'"
    )
    response = client.start_query(QueryStatement=query)
    query_id = response["QueryId"]
    while True:
        response = client.get_query_results(
            EventDataStore=eds_id, QueryId=query_id
        )
        if response["QueryStatus"] == "FINISHED":
            break
    client = boto3.client("dynamodb")
    response = client.put_item(
        TableName=f"{event['table']}",
        Item={
            "date": {"S": str(yesterday)},
            "num": {
                "S": str(response["QueryStatistics"]["TotalResultsCount"])
            },
        },
    )
