import json
import boto3

print('Loading function')

#Load DynamoDB
db = boto3.resource('dynamodb')

def initTable():
    try:
        newTable = db.create_table(
            AttributeDefinitions=[
                {
                    'AttributeName': 'visitorKey'
                    'AttributeType': 'S'
                },
                {
                    'AttributeName': 'visitorCount'
                    'AttributeType': 'N'
                },
            ],
            TableName="static-site-db",
            KeySchema=[{
                'AttributeName': 'visitorKey',
                'KeyType': 'HASH'
            }]

        )

        newTable.wait_until_exists()

        print(f"Table created!")
    except db.exceptions.ResourceInUseException:
        pass

    return db.Table("static-site-db")
table = initTable()


def lambda_handler(event, context):
    #Get count item
    countItem = table.get_item(
        Key={
            'visits': 'visits'
        }
    )

    #Get current visitors
    currentVisitors = countItem['Item']['visitorCount']

    #Increment by 1 and return
    table.update_item(
        Key={
            'visits': 'visits'
        },
        UpdateExpression='SET visitorCount = :val',
        ExpressionAttributeValues={
            ':val': currentVisitors + 1
        }
    )

    return currentVisitors + 1
