# Tạo file htpasswd cho Docker Registry với thông tin đăng nhập (user: oanh, password: oanh)
# Lệnh này tạo một mật khẩu được mã hóa cho registry và lưu vào file htpasswd
# Sử dụng lệnh `htpasswd` của Docker Registry để mã hóa mật khẩu
# docker run --rm --entrypoint htpasswd registry:2.7.0 -Bbn oanh oanh > htpasswd
# Tạo secret chứa thông tin đăng nhập đã mã hóa từ file htpasswd trong Kubernetes
# kubectl create secret generic registry-auth-secret --from-file=htpasswd --namespace mlops --dry-run=client -o yaml | kubectl apply -f -

# Tạo PersistentVolumeClaim (PVC) cho Docker Registry với dung lượng 10Gi sử dụng Longhorn làm storage
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

# Áp dụng PVC đã tạo vào Kubernetes
kubectl apply -f pvc.yaml

# Thêm kho Helm của twuni và cập nhật danh sách các chart
helm repo add twuni https://helm.twun.io
helm repo update

# Tìm kiếm chart Docker Registry từ kho Helm
helm search repo docker-registry

# Tạo file cấu hình Helm cho Docker Registry (service, ingress, persistence, v.v.)
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

# Cài đặt Docker Registry qua Helm với các cấu hình đã tạo
helm upgrade --install docker-registry twuni/docker-registry -f values.yaml --namespace mlops

# Kiểm tra các dịch vụ đang chạy trong namespace mlops
kubectl get svc -n mlops

# Gỡ cài đặt Docker Registry nếu không cần thiết
# helm uninstall docker-registry --namespace mlops

# Tạo và đẩy image Docker vào registry cá nhân đã cài đặt
docker pull nginx:latest
docker tag nginx:latest registry.mylab.com:5000/my-nginx:test
docker push registry.mylab.com:5000/my-nginx:test

# Kéo image từ registry cá nhân về
docker pull registry.mylab.com:5000/my-nginx:test

# Cấu hình registry cho RKE2 để sử dụng registry cá nhân (non-HTTPS)
cat <<EOF > /etc/rancher/rke2/registries.yaml
mirrors:
  registry.mylab.com:5000:
    endpoint:
      - "http://registry.mylab.com:5000"
EOF

# Cấu hình Docker để sử dụng registry không bảo mật (non-HTTPS)
cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries": ["registry.mylab.com:5000"]
}
EOF

# Khởi động lại dịch vụ Docker và RKE2 để áp dụng các cấu hình mới
echo "Restarting Docker..."
sudo systemctl restart docker
sudo systemctl restart rke2-server
# sudo systemctl restart rke2-agent
