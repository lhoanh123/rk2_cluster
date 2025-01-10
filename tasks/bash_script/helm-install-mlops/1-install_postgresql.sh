#!/bin/bash

# Tạo namespace mlops
kubectl create namespace mlops

# Tạo PersistentVolumeClaim cho PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: mlops
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Tạo Deployment cho PostgreSQL
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-deployment
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:14
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              value: "Password1234"
            - name: PGDATA
              value: "/var/lib/postgresql/data/pgdata"
          volumeMounts:
            - mountPath: "/var/lib/postgresql/data"
              name: postgres-storage
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
EOF

# Tạo Service để truy cập PostgreSQL (Loại ClusterIP)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: mlops
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
EOF

# Kiểm tra Service đã được tạo
kubectl get svc -n mlops

# Cài đặt PostgreSQL client (uncomment nếu chạy trên máy cục bộ)
sudo apt update
sudo apt install -y postgresql-client-common postgresql-client

# In ra hướng dẫn kết nối với PostgreSQL
cat <<EOM

PostgreSQL setup is complete.

To connect to the database:
1. Find the External IP of the postgres-service using:
   kubectl get svc -n mlops

2. Use the PostgreSQL client to connect:
   psql -h <EXTERNAL-IP> -p 5432 -U postgres

Once connected, run the following SQL commands:
   CREATE TABLE test_table(id SERIAL PRIMARY KEY, name VARCHAR(50));
   INSERT INTO test_table(name) VALUES ('Kubernetes Persistent Volume');
   INSERT INTO test_table(name) VALUES ('Kubernetes Persistent Volume Claim');
   SELECT * FROM test_table;
EOM

echo "PostgreSQL setup completed successfully."


# Lệnh xóa dịch vụ, deployment và PVC (nếu muốn xóa)
# kubectl delete service postgres-service --namespace mlops
# kubectl delete deployment postgres-deployment --namespace mlops
# kubectl delete persistentvolumeclaim postgres-pvc --namespace mlops
