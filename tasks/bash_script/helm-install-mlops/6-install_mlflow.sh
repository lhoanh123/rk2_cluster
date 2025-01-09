#https://github.com/community-charts/helm-charts/blob/main/charts/mlflow/values.yaml
helm repo add community-charts https://community-charts.github.io/helm-charts

helm repo update 

cat <<EOM 
psql -h 10.43.178.165 -p 5432 -U postgres
Password1234
CREATE DATABASE mlflow_db;
CREATE USER mlflow_user WITH PASSWORD 'mlflow_password';
GRANT ALL PRIVILEGES ON DATABASE mlflow_db TO mlflow_user;

CREATE DATABASE mlflow_auth_db;
CREATE USER auth_user WITH PASSWORD 'auth_password';
GRANT ALL PRIVILEGES ON DATABASE mlflow_auth_db TO auth_user;

\l
EOM

cat <<EOF > Dockerfile
FROM ghcr.io/mlflow/mlflow:v2.19.0

# Install system dependencies for PostgreSQL and S3 support, as well as Python dependencies
RUN apt-get update -y && \\
    apt-get install -y --no-install-recommends \\
    python3-dev \\
    build-essential \\
    pkg-config && \\
    rm -rf /var/lib/apt/lists/* && \\
    # Upgrade pip and install Python dependencies
    pip install --upgrade pip && \\
    pip install psycopg2-binary boto3

# Default command to start bash (or you can modify it to run MLflow server if needed)
CMD ["bash"]

EOF

# Build and push the Docker image to your private registry
docker build -t registry.mylab.com:5000/mlflow:v2 -f Dockerfile .
docker push registry.mylab.com:5000/mlflow:v2

cat <<EOF > pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mlflow-pvc
  namespace: mlops
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: longhorn
EOF

kubectl apply -f pvc.yaml

# # Image of mlflow
# image:
#   # -- The docker image repository to use
#   repository: burakince/mlflow
#   # -- The docker image pull policy
#   pullPolicy: IfNotPresent
#   # -- The docker image tag to use. Default app version
#   tag: ""
# image:
#   # -- The docker image repository to use
#   repository: registry.mylab.com:5000/mlflow
#   # -- The docker image pull policy
#   pullPolicy: Always
#   # -- The docker image tag to use. Default app version
#   tag: "v1"

# extraFlags:
#   - serveArtifacts

cat <<EOF > values.yaml
replicaCount: 1

# Image of mlflow
image:
  repository: registry.mylab.com:5000/mlflow
  # -- The docker image pull policy
  pullPolicy: Always
  # -- The docker image tag to use. Default app version
  tag: "v2"

service:
  type: LoadBalancer
  port: 5000
  name: http
  annotations: {}

backendStore:
  databaseConnectionCheck: true
  postgres:
    enabled: true
    host: "10.43.178.165"
    port: 5432
    database: "mlflow_db"
    user: "mlflow_user"
    password: "mlflow_password"
    driver: "psycopg2"

artifactRoot:
  s3:
    enabled: true
    bucket: "mlflow-artifacts"
    awsAccessKeyId: "CeGeT5fesfdHa4unYt2p" 
    awsSecretAccessKey: "ZxxHWqpOfy8SGzkzGbjMkG86tudAq9KAiPckB5gJ" 
extraEnvVars:
  MLFLOW_S3_ENDPOINT_URL: "https://minio.mylab.com:9000"
  MLFLOW_S3_IGNORE_TLS: true

ingress:
  enabled: true
  className: "nginx"
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - host: mlflow.mylab.com
      paths:
        - path: /
          pathType: ImplementationSpecific

extraVolumes:
  - name: mlflow-volume
    persistentVolumeClaim:
      claimName: mlflow-pvc

auth:
  enabled: false
  adminUsername: "admin"
  adminPassword: "admin"
  defaultPermission: MANAGE
  appName: "basic-auth"
  authorizationFunction: "mlflow.server.auth:authenticate_request_basic_auth"
  sqliteFile: "basic_auth.db"
  sqliteFullPath: ""
  configPath: "/etc/mlflow/auth.ini"
  postgres:
    enabled: true
    host: "10.43.178.165"
    port: 5432 # required
    database: "mlflow_auth_db"
    user: "auth_user"
    password: "auth_password"
    driver: "psycopg2"
EOF

helm upgrade --install mlflow community-charts/mlflow -f values.yaml --namespace mlops

# https://appdev24.com/pages/63/setup-mlflow-on-kubernetes
# helm uninstall mlflow --namespace mlops
python3 -m venv env
source env/bin/activate

pip3 install --upgrade pip
pip3 install mlflow
pip3 install boto3
pip3 install scikit-learn

export MLFLOW_TRACKING_URI=http://mlflow.mylab.com:5000
export MLFLOW_TRACKING_INSECURE_TLS=true
export MLFLOW_S3_ENDPOINT_URL=https://minio.mylab.com:9000
export MLFLOW_S3_IGNORE_TLS=true
export MLFLOW_ARTIFACTS_DESTINATION=s3://mlflow-artifacts
export AWS_ACCESS_KEY_ID=CeGeT5fesfdHa4unYt2p
export AWS_SECRET_ACCESS_KEY=ZxxHWqpOfy8SGzkzGbjMkG86tudAq9KAiPckB5gJ

# git clone https://github.com/mlflow/mlflow
python3 mlflow/examples/sklearn_elasticnet_wine/train.py

# NOTE: review the links mentioned above for guidance on connecting to a managed tracking server, such as the free Databricks Community Edition

# mlflow.set_tracking_uri(uri="http://mlflow.mylab.com:5000")

# kubectl logs mlflow-67cf6d8c9-lk2h2 -n mlops -c mlflow
