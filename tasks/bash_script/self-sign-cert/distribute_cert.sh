#!/bin/bash

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
TRUST_BUNDLE_NAME="my-root-ca-bundle"

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

# Step 1: Create ConfigMap for the certificate
echo "=== Creating ConfigMap for the certificate ==="
kubectl create configmap $CERT_SECRET_NAME --from-file=tls.crt=$(kubectl get secret $CERT_SECRET_NAME -n $CERT_NAMESPACE -o jsonpath="{.data.tls\.crt}" | base64 --decode) -n $CERT_NAMESPACE

# Step 2: Create a DaemonSet to distribute the certificate to all nodes
echo "=== Creating DaemonSet to distribute the certificate ==="
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cert-distributor
  namespace: $CERT_NAMESPACE
spec:
  selector:
    matchLabels:
      app: cert-distributor
  template:
    metadata:
      labels:
        app: cert-distributor
    spec:
      containers:
        - name: cert-distributor
          image: busybox:1.35
          volumeMounts:
            - name: cert-volume
              mountPath: /etc/certs
              readOnly: true
      volumes:
        - name: cert-volume
          configMap:
            name: $CERT_SECRET_NAME
            items:
              - key: tls.crt
                path: cert.pem
EOF

echo "Waiting for DaemonSet pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n "$CERT_NAMESPACE" --timeout=120s

echo "=== All steps completed successfully ==="