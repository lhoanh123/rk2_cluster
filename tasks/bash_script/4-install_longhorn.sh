#!/bin/bash

# Đặt các biến môi trường cho namespace của Longhorn và hostname cho Ingress.
export LONGHORN_NAMESPACE="longhorn-system"
export INGRESS_HOST="longhorn.mylab.com"

# Thêm repository Helm của Longhorn và cập nhật danh sách Helm chart.
echo "Adding Longhorn Helm repository..."
helm repo add longhorn https://charts.longhorn.io
helm repo update

# Tạo namespace cho Longhorn.
echo "Creating Longhorn namespace..."
kubectl create namespace $LONGHORN_NAMESPACE

# Cài đặt Longhorn sử dụng Helm với các cấu hình tùy chỉnh.
echo "Installing Longhorn with custom settings..."
helm upgrade -i longhorn longhorn/longhorn --namespace $LONGHORN_NAMESPACE \
  --set ingress.enabled=true \
  --set ingress.host=$INGRESS_HOST \
  --set defaultSettings.deletingConfirmationFlag=true \
  --set persistence.defaultStorageClass.replicaCount=1 \
  --set persistence.defaultClassReplicaCount=1 \
  --set persistence.reclaimPolicy="Delete"

# Chờ một thời gian để đảm bảo các tài nguyên được triển khai đầy đủ.
echo "Waiting for the Longhorn deployment to complete..."
sleep 30

# Kiểm tra trạng thái của các pod trong namespace Longhorn.
echo "Verifying Longhorn pod status..."
kubectl get pods --namespace $LONGHORN_NAMESPACE

# Một lệnh thay thế để cài đặt Longhorn với cấu hình khác, đã được comment để tham khảo.
# helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system \
#   --set ingress.enabled=true \
#   --set ingress.host=longhorn.mylab.com \
#   --set defaultSettings.deletingConfirmationFlag=true \
#   --set persistence.reclaimPolicy="Delete" \
#   --set persistence.defaultStorageClass.replicaCount=1 \
#   --set persistence.defaultDataLocality="Best-Effort" \
#   --set persistence.defaultClassReplicaCount=1
