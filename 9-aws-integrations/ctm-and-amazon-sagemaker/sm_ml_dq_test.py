import boto3
import pandas as pd
import io
import traceback

# AWS Configuration
BUCKET_NAME = "<YOUR_BUCKET_NAME>"
FILE_KEY = "<YOUR_CSV_FILE_KEY>"

# Minimum requirements
MIN_ROWS = 1000
MIN_COLUMNS = 5

def check_csv_in_s3(bucket, file_key):
    s3 = boto3.client("s3")

    try:
        print(f"🔍 Checking file: s3://{bucket}/{file_key}")

        # Download the CSV file
        response = s3.get_object(Bucket=bucket, Key=file_key)
        csv_data = response["Body"]

        # Read in chunks (handles large files efficiently)
        chunk_size = 5000
        row_count = 0
        column_count = None

        for chunk in pd.read_csv(io.BytesIO(csv_data.read()), chunksize=chunk_size):
            row_count += chunk.shape[0]
            if column_count is None:
                column_count = chunk.shape[1]

        # Validate CSV structure
        if row_count >= MIN_ROWS and column_count > MIN_COLUMNS:
            result = {"status": "✅ CSV meets requirements", "rows": row_count, "columns": column_count}
        else:
            result = {"status": "❌ CSV does not meet requirements", "rows": row_count, "columns": column_count}

        print(result)
        return result

    except Exception as e:
        error_message = f"❌ Error: {str(e)}"
        traceback_details = traceback.format_exc()  # Capture full traceback
        print(error_message)
        print(traceback_details)  # Print full error details

        return {"error": error_message, "traceback": traceback_details}

def lambda_handler(event, context):
    response = check_csv_in_s3(BUCKET_NAME, FILE_KEY)
    return response
