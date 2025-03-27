import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.neural_network import MLPClassifier
import joblib

# Define paths
input_path = "/opt/ml/processing/input/train/processed_data.csv"  # Match pipeline output
model_output_path = "/opt/ml/processing/model/"  # Directory for saved models
data_output_path = "/opt/ml/processing/output/data/"  # Directory to save train and test datasets

try:
    # Check if input file exists
    if not os.path.exists(input_path):
        raise FileNotFoundError(f"Input data file not found at: {input_path}")

    # Load preprocessed data
    print(f"Loading preprocessed data from: {input_path}")
    data = pd.read_csv(input_path)
    print(f"Data loaded successfully. Shape: {data.shape}")

    # Handle missing or invalid values
    print("Handling missing or invalid values...")
    data = data.replace([float('inf'), -float('inf')], float('nan'))
    data = data.dropna()  # Drop rows with NaN values
    print(f"Data shape after cleaning: {data.shape}")

    # Separate features and target
    if 'isFraud' not in data.columns:
        raise ValueError("Target column 'isFraud' is missing in the input data.")

    X = data.drop(columns=['isFraud'])
    y = data['isFraud']

    # Ensure target column is binary and valid
    print("Checking target column validity...")
    if not np.isfinite(y).all():
        raise ValueError("Target column 'isFraud' contains non-finite values.")
    y = (y > 0).astype(int)  # Convert target to binary (1 if > 0, else 0)

    # Split data into training and testing sets
    print("Splitting data into train and test sets...")
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    print(f"Training set size: {X_train.shape}, Test set size: {X_test.shape}")

    # Save train and test datasets
    os.makedirs(data_output_path, exist_ok=True)  # Ensure the data output directory exists
    X_train.to_csv(os.path.join(data_output_path, "X_train.csv"), index=False)
    X_test.to_csv(os.path.join(data_output_path, "X_test.csv"), index=False)
    pd.DataFrame(y_train).to_csv(os.path.join(data_output_path, "y_train.csv"), index=False, header=["isFraud"])
    pd.DataFrame(y_test).to_csv(os.path.join(data_output_path, "y_test.csv"), index=False, header=["isFraud"])
    print(f"Train and test datasets saved in: {data_output_path}")

    # Train models
    print("Training models...")
    models = {
        "logistic_regression": LogisticRegression(),
        "decision_tree": DecisionTreeClassifier(),
        "mlp_classifier": MLPClassifier(max_iter=500)
    }

    os.makedirs(model_output_path, exist_ok=True)  # Ensure the model output directory exists

    for name, model in models.items():
        print(f"Training {name}...")
        model.fit(X_train, y_train)
        model_file = os.path.join(model_output_path, f"{name}.pkl")
        joblib.dump(model, model_file)
        print(f"{name} model saved to: {model_file}")

    print("All models trained and saved successfully.")
    print(f"Models saved in directory: {model_output_path}")

except FileNotFoundError as e:
    print(f"File not found: {e}")
except ValueError as e:
    print(f"Value error: {e}")
except Exception as e:
    print(f"Error during training step: {e}")
