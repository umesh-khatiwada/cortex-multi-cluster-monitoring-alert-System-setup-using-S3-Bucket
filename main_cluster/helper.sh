

#set the username and password for the nginx
cat <<EOF  > nginx-user-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: nginx-user-secrets
  namespace: cortex
stringData:
  .htpasswd: |
      openuser:\$apr1\$4JUX.mq8\$T1E1L5dTWddwtBiULA/KM1
EOF

kubectl apply -f nginx-user-secrets.yaml




#setup the prometheus values.yaml
cat << EOF > values.yaml
config:
  ruler:
    enable_api: true
    rule_path: /rules
  alertmanager:
    enable_api: true
    data_dir: /data

  auth_enabled: true
  api:
    prometheus_http_prefix: '/prometheus'
    response_compression_enabled: true
  ingester:
    lifecycler:
      join_after: 0s
      final_sleep: 0s
      num_tokens: 512
      ring:
        replication_factor: 3
        kvstore:
          store: consul
          prefix: 'collectors/'
          consul:
            host: 'consul-server:8500'
            http_client_timeout: '20s'
            consistent_reads: true
  ruler_storage:
    backend: s3
    s3:
      bucket_name: $ruler_BucketName
      access_key_id: $ruler_AccessKeyId
      secret_access_key: $ruler_SecretAccessKey
      endpoint: $ruler_Endpoint
      region: $ruler_Region
  alertmanager_storage:
    backend: s3
    s3:
      bucket_name: $ruler_BucketName
      access_key_id: $ruler_AccessKeyId
      secret_access_key: $ruler_SecretAccessKey
      endpoint: $ruler_Endpoint
      region: $ruler_Region

  storage:
    engine: blocks
  blocks_storage:
    backend: s3
    s3:
      bucket_name: $blocks_BucketName
      access_key_id: $blocks_AccessKeyId
      secret_access_key: $blocks_SecretAccessKey
      endpoint: $blocks_Endpoint
      region: $blocks_Region

    bucket_store:
      sync_dir: "/data"
    tsdb:
      dir: "/data"

alertmanager:
  enabled: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

distributor:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

ingester:
  autoforget_unhealthy: true
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

ruler:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

querier:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

query_frontend:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

nginx:
  enabled: true
  http_listen_port: 80 
  config:
    setHeaders: 
        X-Scope-OrgID: \$remote_user
    basicAuthSecretName: nginx-user-secrets
    verboseLogging: true
  service:
    type: LoadBalancer
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

store_gateway:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom

compactor:
  serviceMonitor:
    enabled: true
    additionalLabels:
      release: prom
EOF


helm repo add cortex-helm https://cortexproject.github.io/cortex-helm-chart
helm repo update
helm install cortex --namespace cortex -f values.yaml cortex-helm/cortex

cat << EOF > rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: default
EOF


#prometheus-user secrets
cat << EOF > prometheus-users-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: openuser-secrets
  namespace: default
type: Opaque
data:
  user: YmVycnlieXRlcw==
  password: YmVycnlieXRlcw==
EOF
kubectl apply -f prometheus-users-secrets.yaml

#prometheus 
cat << EOF > prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prom-app
  namespace: default
spec:
  enableAdminAPI: false
  image: quay.io/prometheus/prometheus:v2.28.1
  listenLocal: false
  logFormat: logfmt
  logLevel: info
  paused: false
  podMonitorNamespaceSelector: {}
  podMonitorSelector:
    matchLabels:
      release: prom
  portName: web
  probeNamespaceSelector: {}
  probeSelector:
    matchLabels:
      release: prom
  remoteWrite:
  - url: http://cortex-nginx.cortex/api/prom/push
    basicAuth:
        username:
          name: openuser-secrets
          key: user
        password:
          name: openuser-secrets
          key: password
  replicas: 1
  retention: 10d
  routePrefix: /
  ruleNamespaceSelector: {}
  ruleSelector:
    matchLabels:
      app: kube-prometheus-stack
      release: prom
  securityContext:
    fsGroup: 2000
    runAsGroup: 2000
    runAsNonRoot: true
    runAsUser: 1000
  serviceAccountName: prometheus
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector:
    matchLabels:
      release: prom
  shards: 1
  version: v2.28.1
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-app
spec:
  type: LoadBalancer
  ports:
  - name: web
    port: 9092
    protocol: TCP
    targetPort: web
  selector:
    prometheus: prom-app
EOF
kubectl apply -f rbac.yaml
kubectl apply -f prometheus.yaml
