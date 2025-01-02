kubectl create namespace cattle-neuvector-system

helm upgrade -i neuvector neuvector/core --namespace cattle-neuvector-system \
    --set k3s.enabled=true \
    --set k3s.runtimePath=/run/k3s/containerd/containerd.sock \
    --set manager.ingress.enabled=true \
    --set manager.svc.type=ClusterIP \
    --set controller.pvc.enabled=true \
    --set manager.ingress.host=neuvector.10.0.0.15.sslip.io \
    --set global.cattle.url=https://rancher.10.0.0.15.sslip.io \
    --set controller.ranchersso.enabled=true \
    --set rbac=tru

### Wait for the deployment/rollout
sleep 30

### Verify the status of Longhorn
kubectl get pods --namespace cattle-neuvector-system