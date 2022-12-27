from datetime import date, timedelta

import boto3


def lambda_handler(event, context):
    """Lambda Handler"""

    today = date.today()
    yesterday = today - timedelta(days=1)

    client = boto3.client("cloudtrail")
    eds_id = event["eds-urn"].replace('"', "").split("/")[1]

    query = (
        "SELECT userIdentity.arn AS Name, userIdentity.type AS Type, eventName"
        f" FROM {eds_id} WHERE eventTime > '{yesterday} 00:00:00'"
        f" AND eventTime < '{today} 00:00:00'"
    )
    response = client.start_query(QueryStatement=query)
    print(response)
