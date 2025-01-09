#!/bin/bash
# https://oopflow.medium.com/how-to-setup-your-own-self-hosted-dockerhub-private-registry-on-kubernetes-f667e658994a
# Create a YAML file for the namespace


# Create a YAML file for the PVC
cat <<EOF > pvc.yaml
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
      storage: 10Gi
  storageClassName: longhorn
EOF

# Create a YAML file for the registry config
cat <<EOF > registry-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: registry-config
  namespace: mlops
data:
  config.yml: |
    version: 0.1
    log:
      fields:
        service: registry
    storage:
      cache:
        blobdescriptor: inmemory
      filesystem:
        rootdirectory: /var/lib/registry
    delete:
      enabled: true
    http:
      addr: :5000
      headers:
        Access-Control-Allow-Origin: ["*"]
        Access-Control-Allow-Credentials: [true]
        Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
        Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
EOF

# Create a YAML file for the Docker registry deployment and service
cat <<EOF > docker-registry.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry
  template:
    metadata:
      labels:
        app: docker-registry
    spec:
      containers:
      - name: registry
        image: registry:2
        env:
        - name: REGISTRY_HTTP_ADDR
          value: :5000
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        - name: REGISTRY_STORAGE_DELETE_ENABLED
          value: "true"
        ports:
        - containerPort: 5000
          name: registry
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
        - name: registry-config
          mountPath: /etc/docker/registry
      volumes:
      - name: registry-storage
        persistentVolumeClaim:
          claimName: registry-pvc
      - name: registry-config
        configMap:
          name: registry-config
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry
  namespace: mlops
spec:
  selector:
    app: docker-registry
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
  type: LoadBalancer
EOF

# Create a YAML file for the registry UI deployment and service
cat <<EOF > docker-registry-ui.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-registry-ui
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-registry-ui
  template:
    metadata:
      labels:
        app: docker-registry-ui
    spec:
      containers:
        - name: docker-registry-ui
          image: joxit/docker-registry-ui:latest
          ports:
            - containerPort: 80
          env:
            - name: REGISTRY_URL
              valueFrom:
                configMapKeyRef:
                  name: docker-registry-ui-config
                  key: registry_url
            - name: DELETE_IMAGES
              value: "true"
            - name: SINGLE_REGISTRY
              value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: docker-registry-ui
  namespace: mlops
spec:
  selector:
    app: docker-registry-ui
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
EOF

# Apply all configurations
kubectl apply -f pvc.yaml
kubectl apply -f registry-config.yaml
kubectl apply -f docker-registry.yaml

# Wait for LoadBalancer IPs
echo "Waiting for LoadBalancer IPs..."
sleep 30

REGISTRY_IP=$(kubectl get svc docker-registry -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create a YAML file for the ConfigMap dynamically
cat <<EOF > docker-registry-ui-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-registry-ui-config
  namespace: mlops
data:
  registry_url: http://192.168.9.111:5000
EOF

# Apply the ConfigMap
kubectl apply -f docker-registry-ui-config.yaml

kubectl apply -f docker-registry-ui.yaml

# Get LoadBalancer IPs

UI_IP=$(kubectl get svc docker-registry-ui -n mlops -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Docker registry deployed at http://$REGISTRY_IP:5000"
echo "Docker registry UI deployed at http://$UI_IP"

# Variables
REGISTRY_IP="registry.mylab.com"
REGISTRY_PORT="5000"
IMAGE_NAME="my-nginx"
TAG="test"

# Update or Create /etc/docker/daemon.json
DOCKER_CONFIG="/etc/docker/daemon.json"
if [ -f "$DOCKER_CONFIG" ]; then
  echo "Updating $DOCKER_CONFIG..."
  jq '.["insecure-registries"] += ["'"$REGISTRY_IP:$REGISTRY_PORT"'"]' "$DOCKER_CONFIG" > /tmp/daemon.json && mv /tmp/daemon.json "$DOCKER_CONFIG"
else
  echo "Creating $DOCKER_CONFIG..."
  cat <<EOF > "$DOCKER_CONFIG"
{
  "insecure-registries": ["$REGISTRY_IP:$REGISTRY_PORT"]
}
EOF
fi

# Restart Docker

echo "Restarting Docker..."
sudo systemctl restart docker

REGISTRY_IP="192.168.9.111"
REGISTRY_PORT="5000"
IMAGE_NAME="my-nginx"
TAG="test"

# Pull, tag, and push the image
echo "Pulling nginx:latest..."
docker pull nginx:latest

echo "Tagging the image..."
docker tag nginx:latest $REGISTRY_IP:$REGISTRY_PORT/$IMAGE_NAME:$TAG

echo "Pushing the image to $REGISTRY_IP:$REGISTRY_PORT..."
docker push $REGISTRY_IP:$REGISTRY_PORT/$IMAGE_NAME:$TAG

# docker pull nginx:latest
# docker tag nginx:latest 192.168.9.111:5000/my-nginx:test
# docker push 192.168.9.111:5000/my-nginx:test