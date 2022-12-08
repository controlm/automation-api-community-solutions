import boto3

# Table Name
table_name = 'mol-movies-table'

# Dyamodb client
dynamodb_client = boto3.client('dynamodb')

#Item scarface movie
item_scarface = {
    'Title':{'S':'Scaraface'},
    'Year' : {'S': '1983'},
    'Title':{'S':'Criminal'},
    'Year' : {'S': '1984'},
    'Title':{'S':'Scarland'},
    'Year' : {'S': '1985'},
    'Title':{'S':'Criminalminds'},
    'Year' : {'S': '1989'}
}
if __name__ == "__main__":
    response = dynamodb_client.put_item (TableName = table_name, Item = item_scarface )

    print (response)
