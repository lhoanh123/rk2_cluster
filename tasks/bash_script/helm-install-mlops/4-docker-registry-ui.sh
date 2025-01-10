# Thêm kho Helm của Joxit và cập nhật danh sách các chart
helm repo add joxit https://helm.joxit.dev
helm repo update

# Tạo file ConfigMap để cấu hình Docker Registry UI, với URL của registry
cat <<EOF > docker-registry-ui-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-registry-ui-config
  namespace: mlops
data:
  registry_url: http://registry.mylab.com:5000
EOF

# Tạo file cấu hình Helm cho Docker Registry UI (cấu hình UI, service, ingress, v.v.)
cat <<EOF > values.yaml
ui:
  replicas: 1
  title: "My Docker Registry UI"
  dockerRegistryUrl: "http://registry.mylab.com:5000"
  registrySecured: false
  singleRegistry: true
  image: "joxit/docker-registry-ui:2.5.2"
  service:
    type: LoadBalancer
    port: 80
    targetPort: 80
  ingress:
    enabled: true
    host: registry-ui.mylab.com
    path: /
    ingressClassName: nginx
EOF

# Cài đặt Docker Registry UI qua Helm với các cấu hình đã tạo
helm upgrade --install docker-registry-ui joxit/docker-registry-ui -f values.yaml --namespace mlops

# Gỡ cài đặt Docker Registry UI nếu không cần thiết
# helm uninstall docker-registry-ui joxit/docker-registry-ui --namespace mlops
