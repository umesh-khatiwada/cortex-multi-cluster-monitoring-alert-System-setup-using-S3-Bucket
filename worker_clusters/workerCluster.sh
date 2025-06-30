#!/bin/bash

# Creating Kubernetes cluster using Kind
kind create cluster -n monitoring
kubectl config use-context kind-monitoring

# Adding Helm repository for Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Installing Prometheus server using Helm
helm install prometheus-server prometheus-community/prometheus

# Asking user for the Cortex-nginx IP or Domain and Basic Auth credentials
echo "Enter Cortex-nginx IP or Domain (e.g., http://8005.server.hem.xyz.np):"
read cortexNginx

echo "Enter Basic Auth username and password (format: username password):"
read UserName PasswordHttpAuth

# Creating the Prometheus custom values file
cat << EOF > prometheus_values.yaml
server:
  remoteWrite:
  - url: $cortexNginx/api/prom/push
    basic_auth:
      username: $UserName
      password: $PasswordHttpAuth
EOF

# Upgrading Prometheus using the custom values file
helm upgrade -f prometheus_values.yaml prometheus-server prometheus-community/prometheus
