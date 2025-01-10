# Thêm kho Helm của JupyterHub và cập nhật danh sách các chart
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

# Hiển thị các giá trị mặc định của chart JupyterHub và lưu chúng vào file values.yaml
helm show values jupyterhub/jupyterhub > values.yaml

# Cài đặt JupyterHub qua Helm, nếu cài đặt thất bại thì sẽ tự động dọn dẹp
helm upgrade --cleanup-on-fail --install my-jupyter jupyterhub/jupyterhub \
 --namespace mlops \
 --values values.yaml

# Gỡ cài đặt JupyterHub nếu không cần thiết
# helm uninstall my-jupyter jupyterhub/jupyterhub --namespace jhub

# Các dòng sau đây là các lệnh thêm kho Helm khác và cập nhật lại danh sách chart
# helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
# helm repo update
# helm show values jupyterhub/jupyterhub > values.yaml

# Cấu hình thêm cho JupyterHub để sử dụng server app tùy chỉnh (nếu cần)
# cat <<EOF > config.yaml
# # this is the default with JupyterHub 2.0
# singleuser:
#   extraEnv:
#     JUPYTERHUB_SINGLEUSER_APP: "jupyter_server.serverapp.ServerApp"
# EOF

# Cài đặt hoặc nâng cấp JupyterHub với cấu hình tùy chỉnh trong file config.yaml
# helm upgrade --cleanup-on-fail \
#   --install jupyter jupyterhub/jupyterhub \
#   --namespace mlops \
#   --create-namespace \
#   --values config.yaml
