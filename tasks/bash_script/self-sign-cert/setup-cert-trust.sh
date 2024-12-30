#!/bin/bash

set -e

# Variables
TRUST_MANAGER_VERSION="v0.7.0"
NAMESPACE_CERT_MANAGER="cert-manager"
SELF_SIGNED_ISSUER_NAME="selfsigned-issuer"
ROOT_CA_CERT_NAME="my-selfsigned-ca"
ROOT_SECRET_NAME="root-secret"
CLUSTER_ISSUER_NAME="my-ca-issuer"
TRUST_BUNDLE_NAME="root-trust-bundle"
CERT_SECRET_NAME="example-tls"
COMMON_NAME="example.local"
DNS_NAME="example.local"
CERT_NAMESPACE="default"

echo "=== Setting up a SelfSigned ClusterIssuer ==="
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $SELF_SIGNED_ISSUER_NAME
spec:
  selfSigned: {}
EOF

echo "=== Generating the root CA certificate ==="
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $ROOT_CA_CERT_NAME
  namespace: $NAMESPACE_CERT_MANAGER
spec:
  isCA: true
  commonName: $ROOT_CA_CERT_NAME
  secretName: $ROOT_SECRET_NAME
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: $SELF_SIGNED_ISSUER_NAME
    kind: ClusterIssuer
    group: cert-manager.io
EOF
echo "Waiting for root CA secret to be created..."
kubectl wait --for=condition=complete --timeout=120s -n "$NAMESPACE_CERT_MANAGER" job/$ROOT_CA_CERT_NAME

echo "=== Creating a ClusterIssuer with the Root CA ==="
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: $CLUSTER_ISSUER_NAME
spec:
  ca:
    secretName: $ROOT_SECRET_NAME
EOF

echo "=== Installing trust-manager ==="
helm install trust-manager jetstack/trust-manager --namespace "$NAMESPACE_CERT_MANAGER" --version "$TRUST_MANAGER_VERSION"
echo "Waiting for trust-manager pod to be ready..."
kubectl wait --for=condition=Ready pods --all -n "$NAMESPACE_CERT_MANAGER" --timeout=120s

echo "=== Creating a Trust Bundle for the Root CA ==="
kubectl apply -f - <<EOF
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: $TRUST_BUNDLE_NAME
spec:
  sources:
  - secret:
      name: $ROOT_SECRET_NAME
      key: tls.crt
  target:
    configMap:
      key: root-certs.pem
    namespaceSelector:
      matchLabels:
        app.kubernetes.io/managed-by: rancher
EOF

echo "=== Requesting a Certificate ==="
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $CERT_SECRET_NAME
  namespace: $CERT_NAMESPACE
spec:
  secretName: $CERT_SECRET_NAME
  duration: 2160h # 90 days
  renewBefore: 360h # 15 days
  commonName: $COMMON_NAME
  dnsNames:
  - $DNS_NAME
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: $CLUSTER_ISSUER_NAME
    kind: ClusterIssuer
    group: cert-manager.io
EOF
echo "Waiting for certificate secret to be created..."
kubectl wait --for=condition=Ready secret/$CERT_SECRET_NAME --namespace="$CERT_NAMESPACE" --timeout=120s

echo "=== All steps completed successfully ==="
