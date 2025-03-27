import os
import pandas as pd
import joblib
from sklearn.metrics import accuracy_score, precision_score, recall_score, classification_report, confusion_matrix
import json

# Paths
data_path = "/opt/ml/processing/input/data"
model_path = "/opt/ml/processing/input/models"
output_path = "/opt/ml/processing/output"

# Load test data
print("Loading test data...")
X_test = pd.read_csv(os.path.join(data_path, "X_test.csv"))
y_test = pd.read_csv(os.path.join(data_path, "y_test.csv")).values.ravel()
print(f"Test data loaded: X_test shape = {X_test.shape}, y_test shape = {y_test.shape}")

# Define models to evaluate
model_names = ["logistic_regression", "decision_tree", "mlp_classifier"]
metrics = {}

# Evaluate each model
for model_name in model_names:
    print(f"Evaluating model: {model_name}")
    model_file = os.path.join(model_path, f"{model_name}.pkl")
    if not os.path.exists(model_file):
        print(f"Model file {model_file} not found. Skipping...")
        continue

    # Load the model
    model = joblib.load(model_file)

    # Make predictions
    y_pred = model.predict(X_test)

    # Compute evaluation metrics
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, average='weighted')
    recall = recall_score(y_test, y_pred, average='weighted')
    classification_rep = classification_report(y_test, y_pred)
    confusion_mat = confusion_matrix(y_test, y_pred)

    # Save metrics
    metrics[model_name] = {
        "Accuracy": accuracy,
        "Precision": precision,
        "Recall": recall,
        "Classification Report": classification_rep,
        "Confusion Matrix": confusion_mat.tolist()  # Convert to list for JSON serialization
    }

    print(f"Metrics for {model_name}:")
    print(f"Accuracy: {accuracy:.2f}, Precision: {precision:.2f}, Recall: {recall:.2f}")

# Save metrics to output
os.makedirs(output_path, exist_ok=True)
metrics_file = os.path.join(output_path, "evaluation_metrics.json")
with open(metrics_file, "w") as f:
    json.dump(metrics, f, indent=4)
print(f"Evaluation metrics saved to: {metrics_file}")
