# Base image
FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Copy project files
COPY requirements.txt main.py ./

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Command to run the script
CMD ["python", "main.py"]