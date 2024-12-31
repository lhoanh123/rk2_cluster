kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.12.1/manifests/metallb.yaml
# On first install only
kubectl create secret generic -n metallb-system memberlist --fromliteral=secretkey="$(openssl rand -base64 128)"

export DEFAULT_IP_RANGE_START=10.0.0.10
export DEFAULT_IP_RANGE_END=10.0.0.40

export RESERVED_IP_RANGE_START=aa.bb.cc.dd
export RESERVED_IP_RANGE_END=ee.ff.gg.hh

cat <<EOF> metallb-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
 namespace: metallb-system
 name: config
data:
 config: |
 address-pools:
 - name: default
 protocol: layer2
 addresses:
 - ${DEFAULT_IP_RANGE_START}-${DEFAULT_IP_RANGE_END}
 - name: rsvd
 protocol: layer2
 auto-assign: false
 addresses:
 - ${RESERVED_IP_RANGE_START}-${RESERVED_IP_RANGE_END}
EOF

kubectl apply -f metallb-config.yaml

kubectl get configmap config -n metallb-system -o yaml

kubectl get all -n metallb-system