# https://medium.com/@magstherdev/jupyterhub-on-kubernetes-c51953ae9ecd

helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

helm show values jupyterhub/jupyterhub > values.yaml

helm upgrade --cleanup-on-fail --install my-jupyter jupyterhub/jupyterhub \
 --namespace mlops \
 --values values.yaml

# helm uninstall my-jupyter jupyterhub/jupyterhub --namespace jhub

# helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
# helm repo update
# helm show values jupyterhub/jupyterhub > values.yaml

# cat <<EOF > config.yaml
# # this is the default with JupyterHub 2.0
# singleuser:
#   extraEnv:
#     JUPYTERHUB_SINGLEUSER_APP: "jupyter_server.serverapp.ServerApp"
# EOF

# helm upgrade --cleanup-on-fail \
#   --install jupyter jupyterhub/jupyterhub \
#   --namespace mlops \
#   --create-namespace \
#   --values config.yaml