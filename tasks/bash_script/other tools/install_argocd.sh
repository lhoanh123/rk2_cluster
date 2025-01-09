curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# add the helm repo
helm repo add argo https://argoproj.github.io/argo-helm

# install argocd
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set global.domain='cd.yourdomain.com' \
  --set configs.cm.url='https://cd.yourdomain.com' \
  --set configs.cm.users.anonymous.enabled=false \
  --set configs.cm.resource.exclusions[0].apiGroups[0]="*" \
  --set configs.cm.resource.exclusions[0].kinds[0]="PipelineRun" \
  --set configs.cm.resource.exclusions[0].kinds[1]="TaskRun" \
  --set configs.cm.resource.exclusions[0].clusters[0]="*"\
  --set configs.params.application.namespaces="*" \
  --set server.metrics.enabled=true \
  --set server.metrics.serviceMonitor.enabled=true \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set server.ingress.tls=true \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/force-ssl-redirect"=true \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/ssl-passthrough"=true \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/backend-protocol"="HTTP" 


kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# peZHA569o6V4LgO7
kubectl patch service argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd login 192.168.0.116 --username admin --password $password --insecure

argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default

# argocd repo add https://charts.bitnami.com/bitnami --type helm --name bitnami
# argocd repo add https://charts.jetstack.io --type helm --name jetstack
# argocd repo add https://kubernetes-charts.storage.googleapis.com --type helm --name stable
# argocd repo add https://prometheus-community.github.io/helm-chart --type helm --name prometheus-community

# helm uninstall argocd --namespace argocd