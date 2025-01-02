#!/bin/bash

sudo apt-get update

sudo apt install python3-pip -y

# Add Docker's official GPG key:
sudo apt install docker.io -y

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Check and install curl if it's not installed
if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    sudo apt update && sudo apt install -y curl
else
    echo "curl is installed: $(curl --version | head -n 1)"
fi

# Install Helm if it's not installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm is installed: $(helm version --short)"
fi

# Write configuration for Helm chart
mkdir -p /var/lib/rancher/rke2/server/manifests
cat <<EOF > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |
    controller:
      config:
        use-forwarded-headers: true
      extraArgs:
        enable-ssl-passthrough: true
EOF

# Symlink kubectl
KUBECTL_PATH=$(find /var/lib/rancher/rke2/data/ -name kubectl 2>/dev/null)
if [[ -n "$KUBECTL_PATH" ]]; then
    echo "Creating symlink for kubectl..."
    sudo ln -sf "$KUBECTL_PATH" /usr/local/bin/kubectl
else
    echo "kubectl not found in /var/lib/rancher/rke2/data/"
    exit 1
fi

# Set KUBECONFIG environment variable
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" >> ~/.bashrc
source ~/.bashrc