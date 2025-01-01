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
  --set settings.orphanDataCleanup=true \
  --set settings.deletionConfirmation=true \
  --set persistence.defaultStorageClass.retainPolicy="Delete" \
  --set persistence.defaultStorageClass.replicaCount=1 \
  --set persistence.defaultStorageClass.dataLocality="Best-Effort" 

# Wait for the deployment to finish
echo "Waiting for the Longhorn deployment to complete..."
sleep 30

# Verify the status of Longhorn pods
echo "Verifying Longhorn pod status..."
kubectl get pods --namespace $LONGHORN_NAMESPACE

# annotations: {}
# csi:
#   kubeletRootDir: /var/lib/kubelet
# defaultSettings:
#   allowRecurringJobWhileVolumeDetached: true
#   autoCleanupSystemGeneratedSnapshot: true
#   createDefaultDiskLabeledNodes: true
#   defaultDataPath: <Default path "/var/lib/longhorn/"> Provide override path if any.
#   disableRevisionCounter: true
#   mkfsExt4Parameters: '-O ^64bit,^metadata_csum'
#   replicaAutoBalance: least-effort
#   replicaSoftAntiAffinity: false
#   replicaZoneSoftAntiAffinity: true
# persistence:
#   defaultClass: true
#   defaultClassReplicaCount: 1
#   defaultFsType: ext4
#   reclaimPolicy: Delete