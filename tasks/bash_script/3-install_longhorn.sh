#!/bin/bash

# Set variables for your environment
export LONGHORN_NAMESPACE="longhorn-system"
export INGRESS_HOST="longhorn.mylab.com"

# Add and update the Helm repository
echo "Adding Longhorn Helm repository..."
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Create the Longhorn namespace
echo "Creating Longhorn namespace..."
kubectl create namespace $LONGHORN_NAMESPACE

# Install Longhorn using Helm with additional configurations
echo "Installing Longhorn with custom settings..."
helm upgrade -i longhorn longhorn/longhorn --namespace $LONGHORN_NAMESPACE \
  --set ingress.enabled=true \
  --set ingress.host=$INGRESS_HOST \
  --set defaultSettings.deletingConfirmationFlag=true \
  --set persistence.defaultStorageClass.replicaCount=1 \
  --set persistence.defaultClassReplicaCount=1 \
  --set persistence.reclaimPolicy="Delete" 

# Wait for the deployment to finish
echo "Waiting for the Longhorn deployment to complete..."
sleep 30

# Verify the status of Longhorn pods
echo "Verifying Longhorn pod status..."
kubectl get pods --namespace $LONGHORN_NAMESPACE

# helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system \
#   --set ingress.enabled=true \
#   --set ingress.host=longhorn.mylab.com \
#   --set defaultSettings.deletingConfirmationFlag=true \
#   --set persistence.reclaimPolicy="Delete" \
#   --set persistence.defaultStorageClass.replicaCount=1 \
#   --set persistence.defaultDataLocality="Best-Effort" \
#   --set persistence.defaultClassReplicaCount=1 