---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: mlops
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: registry-config
  namespace: mlops
data:
  config.yml: |
    version: 0.1
    log:
      fields:
        service: registry
    storage:
      cache:
        blobdescriptor: inmemory
      filesystem:
        rootdirectory: /var/lib/registry
    delete:
      enabled: true
    http:
      addr: :5000
      headers:
        Access-Control-Allow-Origin: ["*"]
        Access-Control-Allow-Credentials: [true]
        Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
        Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlops
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlops
  template:
    metadata:
      labels:
        app: mlops
    spec:
      containers:
      - name: registry
        image: registry:2.8.3
        env:
        - name: REGISTRY_HTTP_ADDR
          value: :5000
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        - name: REGISTRY_STORAGE_DELETE_ENABLED
          value: "true"
        ports:
        - containerPort: 5000
          name: registry
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
        - name: registry-config
          mountPath: /etc/docker/registry
      volumes:
      - name: registry-storage
        persistentVolumeClaim:
          claimName: registry-pvc
      - name: registry-config
        configMap:
          name: registry-config
---
apiVersion: v1
kind: Service
metadata:
  name: mlops
  namespace: mlops
spec:
  selector:
    app: mlops
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
  type: LoadBalancer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mlops-ui-config
  namespace: mlops
data:
  registry_url: http://192.168.1.68:5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mlops-ui
  namespace: mlops
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mlops-ui
  template:
    metadata:
      labels:
        app: mlops-ui
    spec:
      containers:
        - name: mlops-ui
          image: joxit/mlops-ui:latest
          ports:
            - containerPort: 80
          env:
            - name: REGISTRY_URL
              valueFrom:
                configMapKeyRef:
                  name: mlops-ui-config
                  key: registry_url
            - name: DELETE_IMAGES
              value: "true"
            - name: SINGLE_REGISTRY
              value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: mlops-ui
  namespace: mlops
spec:
  selector:
    app: mlops-ui
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
---