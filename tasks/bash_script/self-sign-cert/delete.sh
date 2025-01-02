#!/bin/bash

# Variables
NAMESPACE_CERT_MANAGER="cert-manager"
SELF_SIGNED_ISSUER_NAME="selfsigned-issuer"
ROOT_CA_CERT_NAME="my-selfsigned-ca"
ROOT_SECRET_NAME="root-secret"
CLUSTER_ISSUER_NAME="my-ca-issuer"
TRUST_BUNDLE_NAME="my-root-ca-bundle"
CERT_SECRET_NAME="example-tls"
CERT_NAMESPACE="default"

echo "=== Starting resource cleanup ==="

# Delete Certificate for TLS
echo "Deleting certificate: $CERT_SECRET_NAME from namespace: $CERT_NAMESPACE..."
kubectl delete certificate $CERT_SECRET_NAME --namespace=$CERT_NAMESPACE
kubectl delete secret $CERT_SECRET_NAME --namespace=$CERT_NAMESPACE

# Delete Trust Bundle
echo "Deleting Trust Bundle: $TRUST_BUNDLE_NAME..."
kubectl delete bundle $TRUST_BUNDLE_NAME --namespace=$NAMESPACE_CERT_MANAGER
kubectl delete configmap $TRUST_BUNDLE_NAME --namespace=$NAMESPACE_CERT_MANAGER

# Delete ClusterIssuer using the Root CA
echo "Deleting ClusterIssuer: $CLUSTER_ISSUER_NAME..."
kubectl delete clusterissuer $CLUSTER_ISSUER_NAME

# Delete Root CA Certificate and Secret
echo "Deleting root CA certificate: $ROOT_CA_CERT_NAME and secret: $ROOT_SECRET_NAME..."
kubectl delete certificate $ROOT_CA_CERT_NAME --namespace=$NAMESPACE_CERT_MANAGER
kubectl delete secret $ROOT_SECRET_NAME --namespace=$NAMESPACE_CERT_MANAGER

# Delete SelfSigned ClusterIssuer
echo "Deleting self-signed ClusterIssuer: $SELF_SIGNED_ISSUER_NAME..."
kubectl delete clusterissuer $SELF_SIGNED_ISSUER_NAME

# Delete trust-manager Helm installation
echo "Uninstalling trust-manager..."
helm uninstall trust-manager --namespace $NAMESPACE_CERT_MANAGER

# Optional: Cleanup namespace if unused
read -p "Do you want to delete the cert-manager namespace (yes/no)? " confirm
if [[ $confirm == "yes" ]]; then
  echo "Deleting namespace: $NAMESPACE_CERT_MANAGER..."
  kubectl delete namespace $NAMESPACE_CERT_MANAGER
else
  echo "Namespace cleanup skipped."
fi

echo "=== Resource cleanup completed ==="
