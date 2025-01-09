#!/bin/bash

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

export DEFAULT_IP_RANGE_START=192.168.9.111
export DEFAULT_IP_RANGE_END=192.168.9.147

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

kubectl apply -f metallb-config.yaml

kubectl get all -n metallb-system

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

kubectl apply -f demo.yaml

# kubectl delete -f demo.yaml