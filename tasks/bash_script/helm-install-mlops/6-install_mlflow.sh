# Thêm kho Helm của community-charts và cập nhật danh sách chart
helm repo add community-charts https://community-charts.github.io/helm-charts
helm repo update

# Tạo cơ sở dữ liệu và người dùng PostgreSQL cho MLflow
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

# Tạo Dockerfile để xây dựng hình ảnh MLflow với PostgreSQL và S3 hỗ trợ
cat <<EOF > Dockerfile
FROM ghcr.io/mlflow/mlflow:v2.19.0

# Cài đặt các phụ thuộc hệ thống và Python cần thiết cho PostgreSQL và S3
RUN apt-get update -y && \\
    apt-get install -y --no-install-recommends \\
    python3-dev \\
    build-essential \\
    pkg-config && \\
    rm -rf /var/lib/apt/lists/* && \\
    # Nâng cấp pip và cài đặt các phụ thuộc Python
    pip install --upgrade pip && \\
    pip install psycopg2-binary boto3

# Lệnh mặc định để bắt đầu bash
CMD ["bash"]
EOF

# Xây dựng và đẩy hình ảnh Docker của MLflow lên registry cá nhân
docker build -t registry.mylab.com:5000/mlflow:v2 -f Dockerfile .
docker push registry.mylab.com:5000/mlflow:v2

# Tạo PersistentVolumeClaim cho MLflow
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

# Cấu hình các thông số của MLflow, bao gồm hình ảnh Docker và kết nối đến PostgreSQL và S3
cat <<EOF > values.yaml
replicaCount: 1

# Cấu hình hình ảnh Docker của MLflow
image:
  repository: registry.mylab.com:5000/mlflow
  pullPolicy: Always
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
    port: 5432
    database: "mlflow_auth_db"
    user: "auth_user"
    password: "auth_password"
    driver: "psycopg2"
EOF

# Cài đặt hoặc nâng cấp MLflow trên Kubernetes
helm upgrade --install mlflow community-charts/mlflow -f values.yaml --namespace mlops

# Gỡ cài đặt MLflow nếu không cần thiết
# helm uninstall mlflow --namespace mlops

# Thiết lập môi trường Python và cài đặt các thư viện cần thiết cho MLflow
python3 -m venv env
source env/bin/activate

pip3 install --upgrade pip
pip3 install mlflow
pip3 install boto3
pip3 install scikit-learn

# Thiết lập các biến môi trường cho MLflow
export MLFLOW_TRACKING_URI=http://mlflow.mylab.com:5000
export MLFLOW_TRACKING_INSECURE_TLS=true
export MLFLOW_S3_ENDPOINT_URL=https://minio.mylab.com:9000
export MLFLOW_S3_IGNORE_TLS=true
export MLFLOW_ARTIFACTS_DESTINATION=s3://mlflow-artifacts
export AWS_ACCESS_KEY_ID=CeGeT5fesfdHa4unYt2p
export AWS_SECRET_ACCESS_KEY=ZxxHWqpOfy8SGzkzGbjMkG86tudAq9KAiPckB5gJ

# Chạy ví dụ MLflow để kiểm tra cài đặt
git clone https://github.com/mlflow/mlflow
python3 mlflow/examples/sklearn_elasticnet_wine/train.py

# mlflow.set_tracking_uri(uri="http://mlflow.mylab.com:5000")

# Kiểm tra logs của MLflow trên Kubernetes
kubectl logs mlflow-67cf6d8c9-lk2h2 -n mlops -c mlflow
