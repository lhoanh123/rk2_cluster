#!/bin/bash

CERT_SECRET_NAME="registry-tls"
CERT_NAMESPACE="mlops"
COMMON_NAME="registry.mylab.com"
DNS_NAME="registry.mylab.com"
CLUSTER_ISSUER_NAME="my-ca-issuer"

echo "=== Requesting a Certificate ==="
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: $CERT_SECRET_NAME
  namespace: $CERT_NAMESPACE
spec:
  isCA: true
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