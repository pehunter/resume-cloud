import json
import boto3

print("Loading function")

# Load DynamoDB
db = boto3.resource("dynamodb")


def lambda_handler(event, context):
    table = db.Table("static-site-db")
    # Get count item
    countItem = table.get_item(Key={"visitorKey": "visits"})

    # If nothing was returned, put the item in.
    if "Item" not in countItem:
        table.put_item(Item={"visitorKey": "visits", "visitorCount": 0})
        countItem = table.get_item(Key={"visitorKey": "visits"})

    # Get current visitors
    currentVisitors = countItem["Item"]["visitorCount"]

    # Increment by 1 and return
    table.update_item(
        Key={"visitorKey": "visits"},
        UpdateExpression="SET visitorCount = :val",
        ExpressionAttributeValues={":val": currentVisitors + 1},
    )

    return currentVisitors + 1
