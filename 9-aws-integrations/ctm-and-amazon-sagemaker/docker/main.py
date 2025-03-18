import os
import pandas as pd
import numpy as np
import boto3
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, recall_score, precision_score, classification_report, confusion_matrix

# Constants
S3_BUCKET = "<YOUR_S3_BUCKET>"  # S3 bucket name (redacted)
S3_OUTPUT_PREFIX = "<YOUR_S3_OUTPUT_PREFIX>/"  # S3 prefix for processed data
LOCAL_INPUT_PATH = "/tmp/<YOUR_CSV_FILE>"  # Path inside the container
LOCAL_OUTPUT_PATH = "/tmp/output.csv"  # Local output path in the container

# Function to upload file from local path to S3
def upload_to_s3(local_path, bucket, s3_key):
    print(f"Uploading {local_path} to bucket {bucket} as {s3_key}")
    s3 = boto3.client('s3')
    s3.upload_file(local_path, bucket, s3_key)

# Function to preprocess data
def preprocess_data(input_path, output_file_name="processed_data.csv"):
    """
    Preprocess data and save the processed file locally.
    """
    # Load data
    print(f"Loading data from {input_path}")
    data = pd.read_csv(input_path)

    # Dropping unnecessary columns
    print("Dropping unnecessary columns...")
    columns_to_drop = ['oldbalanceOrg', 'newbalanceOrig', 'oldbalanceDest', 'newbalanceDest', 'nameOrig', 'nameDest']
    data.drop(columns_to_drop, axis=1, inplace=True)

    # Encoding categorical columns into numerical data
    print("Encoding categorical data...")
    le = LabelEncoder()
    data['type'] = le.fit_transform(data['type'])

    # Separating feature variables and class variable
    print("Separating features and target variable...")
    X = data.drop('isFraud', axis=1)
    y = data['isFraud']

    # Standardizing the features
    print("Standardizing features...")
    sc = StandardScaler()
    X = sc.fit_transform(X)

    # Saving the processed data to a local output file
    data.to_csv(output_file_name, index=False)
    print(f"Processed data saved locally at {output_file_name}")

# Function to download file from S3
def download_from_s3(bucket_name, s3_key, local_path):
    s3 = boto3.client('s3')
    print(f"Downloading {s3_key} from bucket {bucket_name} to {local_path}")
    s3.download_file(bucket_name, s3_key, local_path)

# Main script execution
if __name__ == "__main__":
    # Download the input data from S3
    download_from_s3(S3_BUCKET, "<YOUR_CSV_FILE>", LOCAL_INPUT_PATH)

    # Process the data
    preprocess_data(LOCAL_INPUT_PATH, LOCAL_OUTPUT_PATH)

    # Upload the processed data to S3
    upload_to_s3(LOCAL_OUTPUT_PATH, S3_BUCKET, S3_OUTPUT_PREFIX + "processed_data.csv")
