#!/bin/bash

CERT_SECRET_NAME="minio-tls"
CERT_NAMESPACE="mlops"
COMMON_NAME="minio.local"
DNS_NAME="minio.local"
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
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: $CLUSTER_ISSUER_NAME
    kind: ClusterIssuer
    group: cert-manager.io
EOF

CERT_SECRET_NAME="minio-ui-tls"
CERT_NAMESPACE="mlops"
COMMON_NAME="minio-ui.local"
DNS_NAME="minio-ui.local"
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
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: $CLUSTER_ISSUER_NAME
    kind: ClusterIssuer
    group: cert-manager.io
EOF

# # Update /etc/hosts
# echo "127.0.0.1 minio.local" | sudo tee -a /etc/hosts
# echo "127.0.0.1 minio-ui.local" | sudo tee -a /etc/hosts

# Create namespace
kubectl create namespace mlops

# Create TLS secrets
# openssl req -x509 -nodes -days 365 \
#     -subj "/C=DE/ST=Berlin/L=Berlin/O=appdev24/OU=dev/CN=registry.local" \
#     -newkey rsa:4096 -keyout selfsigned.key \
#     -out selfsigned.crt

kubectl create secret tls minio-tls --namespace mlops --cert=selfsigned.crt --key=selfsigned.key
kubectl create secret tls minio-ui-tls --namespace mlops --cert=selfsigned-ui.crt --key=selfsigned-ui.key

# Create PersistentVolumeClaim
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: mlops
spec:
  storageClassName: longhorn
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Create Deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio-deployment
  namespace: mlops
  labels:
    app: minio-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
        - name: minio-server
          image: quay.io/minio/minio:latest
          ports:
          - containerPort: 9000
            hostPort: 9000
          - containerPort: 9001
            hostPort: 9001
          env:
            - name: MINIO_ROOT_USER
              value: admin
            - name: MINIO_ROOT_PASSWORD
              value: Password1234
          command:
            - /bin/bash
            - -c
          args:
              - minio server /data --console-address :9001
          volumeMounts:
            - mountPath: /data
              name: data
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          readinessProbe:
            httpGet:
              path: /minio/health/ready
              port: 9000
          livenessProbe:
            httpGet:
              path: /minio/health/live
              port: 9000
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: minio-pvc
EOF

# Create Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: minio-service
  namespace: mlops
  labels:
    app: minio-service
spec:
  type: ClusterIP
  selector:
    app: minio
  ports:
  - name: api
    protocol: TCP
    port: 9000
    targetPort: 9000
  - name: webui
    protocol: TCP
    port: 9001
    targetPort: 9001
EOF

# Create Ingress for MinIO
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minio-ingress
  namespace: mlops
  labels:
    app: minio-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: minio.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio-service
            port:
              number: 9000
  tls:
  - hosts:
    - minio.local
    secretName: minio-tls
EOF

# Create Ingress for MinIO UI
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minio-ui-ingress
  namespace: mlops
  labels:
    app: minio-ui-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: minio-ui.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio-service
            port:
              number: 9001
  tls:
  - hosts:
    - minio-ui.local
    secretName: minio-ui-tls
EOF

# Output Access and Secret Keys
echo "Access-Key: hLb77XSAssSoLmiXUbgU"
echo "Secret-Key: x6GGmJ81P0GyOjGBgT2xyYQvbZJywEqKLmHU3ddC"

echo "MinIO setup completed successfully."

  # kubectl delete ingress minio-ingress --namespace mlops
  # kubectl delete ingress minio-ui-ingress --namespace mlops

  # # Delete Service
  # kubectl delete service minio-service --namespace mlops

  # # Delete Deployment
  # kubectl delete deployment minio-deployment --namespace mlops

  # # Delete PersistentVolumeClaim
  # kubectl delete persistentvolumeclaim minio-pvc --namespace mlops

  # # Delete TLS Secrets
  # kubectl delete secret minio-tls --namespace mlops
  # kubectl delete secret minio-ui-tls --namespace mlops
