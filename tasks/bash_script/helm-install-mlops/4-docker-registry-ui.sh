helm repo add joxit https://helm.joxit.dev
helm repo update

# Create a YAML file for the ConfigMap dynamically
cat <<EOF > docker-registry-ui-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-registry-ui-config
  namespace: mlops
data:
  registry_url: http://registry.mylab.com:5000
EOF

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

helm upgrade --install docker-registry-ui joxit/docker-registry-ui -f values.yaml --namespace mlops

# helm uninstall docker-registry-ui joxit/docker-registry-ui --namespace mlops
