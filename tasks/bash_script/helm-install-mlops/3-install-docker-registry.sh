# docker run --rm --entrypoint htpasswd registry:2.7.0 -Bbn oanh oanh > htpasswd

# oanh:$2y$05$C9D.xoX9Lr6UBmJCAkF6dOC4gDl6.dZ7sshkoUugc9I15skWp4ev2
# https://kb.leaseweb.com/kb/kubernetes/kubernetes-deploying-a-docker-registry-on-kubernetes/
# https://github.com/twuni/docker-registry.helm/blob/main/values.yaml

# kubectl create secret generic registry-auth-secret --from-file=htpasswd --namespace mlops --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF > pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-registry-pvc
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

helm repo add twuni https://helm.twun.io

helm repo update

helm search repo docker-registry

cat <<EOF > values.yaml
---
# Default values for docker-registry.
replicaCount: 1

service:
  name: registry
  type: LoadBalancer
  port: 5000

ingress:
  enabled: true
  className: nginx
  path: /
  hosts:
    - registry.mylab.com
  annotations:
    kubernetes.io/ingress.class: nginx

persistence:
  enabled: true
  size: 10Gi
  existingClaim: docker-registry-pvc
  deleteEnabled: true
  accessMode: ReadWriteOnce

configData:
  version: 0.1
  log:
    fields:
      service: registry
  storage:
    cache:
      blobdescriptor: inmemory
  http:
    addr: :5000
    headers:
      Access-Control-Allow-Origin: ["*"]
      Access-Control-Allow-Credentials: [true]
      Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
      Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    debug:
      addr: :5001
      prometheus:
        enabled: false
        path: /metrics
  health:
    storagedriver:
      enabled: true
      interval: 10s
      threshold: 3
EOF

helm upgrade --install docker-registry twuni/docker-registry -f values.yaml --namespace mlops

kubectl get svc -n mlops

# helm uninstall docker-registry --namespace mlops

docker pull nginx:latest
docker tag nginx:latest registry.mylab.com:5000/my-nginx:test
docker push registry.mylab.com:5000/my-nginx:test

docker pull registry.mylab.com:5000/my-nginx:test

cat <<EOF > /etc/rancher/rke2/registries.yaml
mirrors:
  registry.mylab.com:5000:
    endpoint:
      - "http://registry.mylab.com:5000"
EOF

REGISTRY_IP="registry.mylab.com"
REGISTRY_PORT="5000"

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
sudo systemctl restart rke2-server
# sudo systemctl restart rke2-server
