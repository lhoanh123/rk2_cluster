#!/bin/bash

# Create self-signed certificate
openssl req -x509 -nodes -days 365 \
    -subj "/C=VN/ST=DongNai/L=BienHoa/O=UIT/OU=UIT/CN=mlflow-tracking.local" \
    -newkey rsa:4096 -keyout selfsigned.key \
    -out selfsigned.crt

# Update /etc/hosts
echo "127.0.0.1 mlflow-tracking.local" | sudo tee -a /etc/hosts

# Create namespace
kubectl create namespace mlops

# Create Kubernetes TLS Secret
kubectl create secret tls mlflow-tracking-tls --namespace mlops --cert=selfsigned.crt --key=selfsigned.key

# Create Docker registry secret
kubectl create secret docker-registry regcred --namespace mlops \
  --docker-server=registry.local:5000 \
  --docker-username=admin \
  --docker-password=Passw0rd1234

# Write Dockerfile
cat <<EOF > Dockerfile
FROM ghcr.io/mlflow/mlflow:v2.16.2

RUN apt-get -y update && \\
    apt-get -y install python3-dev build-essential pkg-config && \\
    pip install --upgrade pip && \\
    pip install psycopg2-binary boto3

CMD ["bash"]
EOF

# Build and push Docker image
docker build -t registry.local:5000/mlflow:v1 -f Dockerfile .
docker push registry.local:5000/mlflow:v1

# Create deployment manifest
cat <<EOF > mlflow-tracking-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlflow-tracking-deployment
  namespace: mlops
  labels:
    app: mlflow-tracking-deployment
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
      imagePullSecrets:
        - name: regcred
      containers:
      - name: mlflow-tracking
        image: registry.local:5000/mlflow:v1
        ports:
        - containerPort: 5000
        env:
          - name: MLFLOW_S3_ENDPOINT_URL
            value: "http://minio-service:9000"
          - name: MLFLOW_S3_IGNORE_TLS
            value: "true"
          - name: AWS_ACCESS_KEY_ID
            value: "admin"
          - name: AWS_SECRET_ACCESS_KEY
            value: "Password1234"
        command: ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "postgresql+psycopg2://postgres:Password1234@postgres-service:5432/postgres", "--default-artifact-root", "s3://mlflow-artifacts"]
EOF
kubectl apply -f mlflow-tracking-deploy.yaml

# Create service manifest
cat <<EOF > mlflow-tracking-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: mlflow-tracking-service
  namespace: mlops
  labels:
    app: mlflow-tracking-service
spec:
  type: ClusterIP
  selector:
    app: mlflow
  ports:
  - name: tcp
    protocol: TCP
    port: 5000
    targetPort: 5000
EOF
kubectl apply -f mlflow-tracking-svc.yaml

# Create ingress manifest
cat <<EOF > mlflow-tracking-ing.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mlflow-tracking-ingress
  namespace: mlops
  labels:
    app: mlflow-tracking-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: mlflow-tracking.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: mlflow-tracking-service
            port:
              number: 5000
  tls:
  - hosts:
    - mlflow-tracking.local
    secretName: mlflow-tracking-tls
EOF
kubectl apply -f mlflow-tracking-ing.yaml

# Remote Tracking Server Details
export MLFLOW_TRACKING_URI=https://mlflow-tracking.local
export MLFLOW_TRACKING_INSECURE_TLS=true
export MLFLOW_S3_ENDPOINT_URL=https://minio.local
export MLFLOW_S3_IGNORE_TLS=true
export MLFLOW_ARTIFACTS_DESTINATION=s3://mlflow-artifacts
export AWS_ACCESS_KEY_ID=LmxP6ZEYgJRxRE9tzbUM
export AWS_SECRET_ACCESS_KEY=bwygxJDYc9PmYqthNPhdNFVIeaBrpk4OsPMMVuSb

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
