kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-core.yaml

kubectl apply -l knative.dev/crd-install=true -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/istio.yaml
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/istio.yaml

kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/net-istio.yaml

kubectl label namespace knative-serving istio-injection=enabled

kubectl --namespace istio-system get service istio-ingressgateway

kubectl patch configmap/config-domain \
    --namespace knative-serving \
    --type merge \
    --patch '{"data":{"knative.mlopsdemo.local":""}}'

cat <<EOF > kserve-deploy.sh
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "knative-serving"
spec:
  mtls:
    mode: PERMISSIVE
EOF

kubectl apply -f kserve-deploy.sh


# # Set the namespace
# NAMESPACE="knative-serving"

# # Delete Knative Serving CRDs
# kubectl delete -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-crds.yaml

# # Delete Knative Serving core components
# kubectl delete -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-core.yaml

# # Delete Istio components
# kubectl delete -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/net-istio.yaml
# kubectl delete -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/istio.yaml

# # Delete the PeerAuthentication config
# kubectl delete -f kserve-deploy.sh

# # Optionally, delete the namespace if it's no longer needed
# # kubectl delete namespace $NAMESPACE

# # Print completion message
# echo "All Knative and Istio resources have been deleted."