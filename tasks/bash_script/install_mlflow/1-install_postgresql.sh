#!/bin/bash

# Create namespace
kubectl create namespace mlops

# Create PersistentVolumeClaim
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
      storage: 1Gi
EOF

# Create Deployment
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
          image: postgres:13
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

# Create Service
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
    - port: 5433
      targetPort: 5432
EOF

# Verify Service
kubectl get svc -n mlops

# Install PostgreSQL client (uncomment if running on a local machine)
sudo apt update
sudo apt install -y postgresql-client-common postgresql-client

# Print instructions for accessing PostgreSQL
cat <<EOM

PostgreSQL setup is complete.

To connect to the database:
1. Find the Cluster IP of the postgres-service using:
   kubectl get svc -n mlops

2. Use the PostgreSQL client to connect:
   psql -h <CLUSTER_IP> -p 5433 -U postgres
or:
   kubectl port-forward svc/postgres-service 5433:5433
   psql -h 127.0.0.1 -p 5433 -U postgres -W

Once connected, run the following SQL commands:
   CREATE TABLE test_table(id SERIAL PRIMARY KEY, name VARCHAR(50));
   INSERT INTO test_table(name) VALUES ('Kubernetes Persistent Volume');
   INSERT INTO test_table(name) VALUES ('Kubernetes Persistent Volume Claim');
   SELECT * FROM test_table;
EOM

echo "PostgreSQL setup completed successfully."
