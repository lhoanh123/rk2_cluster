curl -L https://istio.io/downloadIstio | sh -

cd istio-1.24.2

export PATH=$PWD/bin:$PATH

istioctl install -y