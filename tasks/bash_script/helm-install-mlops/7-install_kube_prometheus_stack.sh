# Thêm kho Helm của Prometheus và cập nhật danh sách chart
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Tạo namespace "monitoring" và cài đặt Prometheus cùng các thành phần theo dõi từ kube-prometheus-stack
kubectl create ns monitoring
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring

# Lấy mật khẩu admin của Grafana từ secret và giải mã
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Gỡ cài đặt Prometheus và các tài nguyên liên quan
# helm uninstall prometheus -n monitoring

# Xóa các CRD liên quan đến Prometheus và các tài nguyên theo dõi
# kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
# kubectl delete crd alertmanagers.monitoring.coreos.com
# kubectl delete crd podmonitors.monitoring.coreos.com
# kubectl delete crd probes.monitoring.coreos.com
# kubectl delete crd prometheuses.monitoring.coreos.com
# kubectl delete crd prometheusrules.monitoring.coreos.com
# kubectl delete crd servicemonitors.monitoring.coreos.com
# kubectl delete crd thanosrulers.monitoring.coreos.com
