#!/bin/bash

# Variables
NAMESPACE="mlops"
CERT_NAME="mlflow-tracking-tls"
SECRET_NAME="mlflow-tracking-tls"
CERT_FILE="mlflow-tracking.crt"
KEY_FILE="mlflow-tracking.key"
CA_FILE="ca.crt"

echo "=== Fetching certificate details from secret ==="

# Ensure the secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" > /dev/null 2>&1; then
  echo "Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'."
  exit 1
fi

# Extract certificate
echo "Extracting certificate..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data['tls\.crt']}" | base64 -d > "$CERT_FILE"
echo "Certificate saved to $CERT_FILE"

# Extract private key
echo "Extracting private key..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data['tls\.key']}" | base64 -d > "$KEY_FILE"
echo "Private key saved to $KEY_FILE"

# Extract CA certificate (optional)
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data['ca\.crt']}" > /dev/null 2>&1; then
  echo "Extracting CA certificate..."
  kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data['ca\.crt']}" | base64 -d > "$CA_FILE"
  echo "CA certificate saved to $CA_FILE"
else
  echo "No CA certificate found in secret."
fi

echo "=== Certificate retrieval complete ==="
