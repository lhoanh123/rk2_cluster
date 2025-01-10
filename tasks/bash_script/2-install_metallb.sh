#!/bin/bash

# Áp dụng cấu hình cài đặt MetalLB theo dạng native.
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Đợi câu lệnh trên chạy xong trước khi apply các câu lệnh bên dưới
echo "Waiting for the Metallb deployment to complete..."
sleep 30

# Đặt dải IP mặc định để MetalLB sử dụng làm địa chỉ IP LoadBalancer.
export DEFAULT_IP_RANGE_START=192.168.9.111
export DEFAULT_IP_RANGE_END=192.168.9.147

# Tạo file cấu hình MetalLB để khai báo IPAddressPool và L2Advertisement.
cat <<EOF > metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
    name: first-pool
    namespace: metallb-system
spec:
    addresses:
    - ${DEFAULT_IP_RANGE_START}-${DEFAULT_IP_RANGE_END}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
    name: example
    namespace: metallb-system
EOF

# Áp dụng cấu hình IPAddressPool và L2Advertisement cho MetalLB.
kubectl apply -f metallb-config.yaml

# Hiển thị tất cả tài nguyên trong namespace `metallb-system` để kiểm tra trạng thái.
kubectl get all -n metallb-system

# Tạo file demo.yaml để triển khai một ứng dụng ví dụ với Deployment và Service.
cat <<EOF > demo.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      run: demo
  template:
    metadata:
      labels:
        run: demo
    spec:
      containers:
      - name: demo
        image: klimenta/serverip
        ports:
        - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: loadbalancer
spec:
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
  type: LoadBalancer
  selector:
    run: demo
EOF

# Áp dụng cấu hình của Deployment và Service.
kubectl apply -f demo.yaml

# Lệnh xóa ứng dụng (được comment để tránh xóa ngay lập tức).
# kubectl delete -f demo.yaml
