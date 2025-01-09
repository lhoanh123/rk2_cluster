#!/bin/bash

# Create self-signed certificate

CERT_SECRET_NAME="mlflow-tracking-tls"
CERT_NAMESPACE="mlops"
COMMON_NAME="mlflow-tracking.local"
DNS_NAME="mlflow-tracking.local"
CLUSTER_ISSUER_NAME="my-ca-issuer"

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

# Create a Dockerfile for MLflow image
cat <<EOF > Dockerfile
FROM ghcr.io/mlflow/mlflow:v2.16.2

RUN apt-get -y update && \\
    apt-get -y install python3-dev build-essential pkg-config && \\
    pip install --upgrade pip && \\
    pip install psycopg2-binary boto3

CMD ["bash"]
EOF

# Build and push the Docker image to your private registry
docker build -t registry.mylab.com:5000/mlflow:v1 -f Dockerfile .
docker push registry.mylab.com:5000/mlflow:v1

# Set up environment variables for MLflow configuration
# export MLFLOW_TRACKING_URI=https://mlflow-tracking.local
# export MLFLOW_TRACKING_INSECURE_TLS=true
# export MLFLOW_S3_ENDPOINT_URL=https://minio.local:9000
# export MLFLOW_S3_IGNORE_TLS=true
# export MLFLOW_ARTIFACTS_DESTINATION=s3://mlflow-artifacts
# export AWS_ACCESS_KEY_ID=hLb77XSAssSoLmiXUbgU
# export AWS_SECRET_ACCESS_KEY=x6GGmJ81P0GyOjGBgT2xyYQvbZJywEqKLmHU3ddC

# Create deployment manifest for MLflow tracking
cat <<EOF > mlflow-tracking-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-tracking-deployment
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlflow
  template:
    metadata:
      labels:
        app: mlflow
    spec:
      containers:
      - name: mlflow-tracking
        image: 192.168.9.111:5000/mlflow:v1  # Use HTTP here
        imagePullPolicy: Always  # Forces a fresh image pull
        ports:
        - containerPort: 5000
        env:
        - name: MLFLOW_S3_ENDPOINT_URL
          value: http://minio.local:9000
        - name: MLFLOW_S3_IGNORE_TLS
          value: "true"
        - name: AWS_ACCESS_KEY_ID
          value: hLb77XSAssSoLmiXUbgU
        - name: AWS_SECRET_ACCESS_KEY
          value: x6GGmJ81P0GyOjGBgT2xyYQvbZJywEqKLmHU3ddC
        command: ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "postgresql+psycopg2://postgres:Password1234@postgres-service:5432/postgres", "--default-artifact-root", "s3://mlflow-artifacts"]
EOF

# Apply the MLflow tracking deployment
kubectl apply -f mlflow-tracking-deploy.yaml
# kubectl delete -f mlflow-tracking-deploy.yaml

# Create service manifest for MLflow tracking
cat <<EOF > mlflow-tracking-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: mlflow-tracking-service
  namespace: mlops
  labels:
    app: mlflow-tracking-service
spec:
  type: LoadBalancer
  selector:
    app: mlflow
  ports:
  - name: tcp
    protocol: TCP
    port: 5000
    targetPort: 5000
EOF

# Apply the MLflow tracking service
kubectl apply -f mlflow-tracking-svc.yaml

# # Create ingress manifest for MLflow tracking
# cat <<EOF > mlflow-tracking-ing.yaml
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: mlflow-tracking-ingress
#   namespace: mlops
#   labels:
#     app: mlflow-tracking-ingress
#   annotations:
#     nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
#     nginx.ingress.kubernetes.io/ssl-redirect: "true"
# spec:
#   ingressClassName: nginx
#   rules:
#   - host: mlflow-tracking.local
#     http:
#       paths:
#       - path: /
#         pathType: Prefix
#         backend:
#           service:
#             name: mlflow-tracking-service
#             port:
#               number: 5000
#   tls:
#   - hosts:
#     - mlflow-tracking.local
#     secretName: mlflow-tracking-tls
# EOF

# # Apply the MLflow tracking ingress
# kubectl apply -f mlflow-tracking-ing.yaml

# Wait for the services to be ready and get the LoadBalancer IPs
echo "Waiting for services to be ready..."

# Get LoadBalancer IP for the MLflow Tracking service
TRACKING_IP=$(kubectl get svc mlflow-tracking-service -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "MLflow Tracking UI is available at http://$TRACKING_IP:5000"

# # Get LoadBalancer IP for the Ingress (if used)
# INGRESS_IP=$(kubectl get ingress mlflow-tracking-ingress -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# echo "MLflow Tracking is accessible via ingress at http://$INGRESS_IP"


mkdir mlflow-testing
cd mlflow-testing

python3 -m venv env
source env/bin/activate

pip3 install --upgrade pip
pip3 install mlflow
pip3 install boto3
pip3 install scikit-learn

git clone https://github.com/mlflow/mlflow
python3 mlflow/examples/sklearn_elasticnet_wine/train.py
