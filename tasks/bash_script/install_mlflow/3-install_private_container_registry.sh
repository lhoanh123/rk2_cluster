#!/bin/bash

# Create namespaces
kubectl create namespace mlops

# Generate self-signed certificate for Registry
openssl req -x509 -nodes -days 365 \
    -subj "/C=VN/ST=DongNai/L=BienHoa/O=UIT/OU=UIT/CN=registry.local" \
    -newkey rsa:4096 -keyout registry.key \
    -out registry.crt

# Update /etc/hosts
echo "127.0.0.1    registry.local" | sudo tee -a /etc/hosts

# Create TLS secrets
kubectl create secret tls registry-tls --namespace mlops --cert=registry.crt --key=registry.key

# Create authentication secret
docker run --entrypoint htpasswd httpd:2 -Bbn admin Passw0rd1234 > htpasswd
kubectl create secret generic registry-auth --namespace mlops --from-literal=htpasswd="$(cat htpasswd)"

# Create PersistentVolumeClaim for storage
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: mlops
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: longhorn
EOF

# Create Deployment for the registry
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry-deployment
  namespace: mlops
  labels:
    app: registry-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
        - name: registry-server
          image: registry:2.8.3
          ports:
          - containerPort: 5000
          env:
            - name: REGISTRY_HTTP_TLS_CERTIFICATE
              value: /etc/ssl/docker/tls.crt
            - name: REGISTRY_HTTP_TLS_KEY
              value: /etc/ssl/docker/tls.key
            - name: REGISTRY_AUTH
              value: "htpasswd"
            - name: REGISTRY_AUTH_HTPASSWD_REALM
              value: "Registry Realm"
            - name: REGISTRY_AUTH_HTPASSWD_PATH
              value: "/auth/htpasswd"
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
          command:
          - /bin/registry
          - serve
          - /etc/docker/registry/config.yml
          volumeMounts:
            - name: registry-storage
              mountPath: "/var/lib/registry"
            - name: registry-certs
              mountPath: "/etc/ssl/docker"
              readOnly: true
            - name: registry-auth
              mountPath: "/auth"
              readOnly: true
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
            requests:
              cpu: 100m
              memory: 128Mi
          readinessProbe:
            httpGet:
              scheme: HTTPS
              path: /
              port: 5000
          livenessProbe:
            httpGet:
              scheme: HTTPS
              path: /
              port: 5000
      volumes:
        - name: registry-storage
          persistentVolumeClaim:
            claimName: registry-pvc
        - name: registry-certs
          secret:
            secretName: registry-tls
        - name: registry-auth
          secret:
            secretName: registry-auth
            items:
            - key: htpasswd
              path: htpasswd
EOF

# Create Service for the registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: registry-service
  namespace: mlops
  labels:
    app: registry-service
spec:
  type: ClusterIP
  selector:
    app: registry
  ports:
  - name: tcp
    protocol: TCP
    port: 5000
    targetPort: 5000
EOF

# Create Ingress for the registry
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry-ingress
  namespace: mlops
  labels:
    app: registry-ingress
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: registry.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: registry-service
            port:
              number: 5000
  tls:
  - hosts:
    - registry.local
    secretName: registry-tls
EOF

# Test the setup
docker login registry.local:5000 -u admin -p Passw0rd1234
docker pull nginx:latest
docker tag nginx:latest registry.local:5000/my-nginx:test
docker push registry.local:5000/my-nginx:test

docker image remove nginx:latest
docker image remove registry.local:5000/my-nginx:test
docker pull registry.local:5000/my-nginx:test

echo "Private container registry setup completed successfully."
