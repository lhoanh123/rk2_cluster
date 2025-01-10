#!/bin/bash

# Đặt các biến môi trường cho hostname của Rancher và mật khẩu bootstrap.
export HOSTNAME="rancher.mylab.com"
export BOOTSTRAP_PASSWORD="admin"

# Thêm các repository Helm của Rancher và Jetstack (chứa cert-manager).
echo "Adding Rancher and Jetstack Helm repositories..."
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io

# Cập nhật danh sách repository Helm để lấy thông tin biểu đồ mới nhất.
echo "Updating Helm repositories..."
helm repo update

# Áp dụng CRD (Custom Resource Definitions) cho cert-manager.
echo "Applying cert-manager CRD..."

# Cài đặt hoặc nâng cấp cert-manager từ Helm chart.
echo "Installing or upgrading cert-manager..."
helm upgrade -i cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

# Cài đặt hoặc nâng cấp Rancher từ Helm chart.
echo "Installing or upgrading Rancher..."
helm upgrade -i rancher rancher-latest/rancher \
  --create-namespace \
  --namespace cattle-system \
  --set hostname="${HOSTNAME}" \             # Cấu hình hostname cho Rancher.
  --set bootstrapPassword="${BOOTSTRAP_PASSWORD}" \  # Đặt mật khẩu bootstrap mặc định.
  --set replicas=1 \                         # Đặt số bản sao (replica) của Rancher là 1.
  --set service.type="LoadBalancer"          # Sử dụng kiểu service LoadBalancer.

# Dòng bên dưới là một phiên bản khác của lệnh cài đặt Rancher, đã được comment.
# helm upgrade -i rancher rancher-latest/rancher \
#   --create-namespace \
#   --namespace cattle-system \
#   --set hostname=rancher.mylab.com \
#   --set bootstrapPassword=admin \
#   --set replicas=1 \
#   --set service.type="LoadBalancer"

# Hiển thị thông báo hoàn thành cài đặt.
echo "Installation completed."

# Lệnh gỡ cài đặt Rancher đã được comment để tránh xóa Rancher.
# helm uninstall rancher --namespace cattle-system

# Một số ghi chú khác (có thể là tài khoản và mật khẩu mẫu hoặc dữ liệu không liên quan).
