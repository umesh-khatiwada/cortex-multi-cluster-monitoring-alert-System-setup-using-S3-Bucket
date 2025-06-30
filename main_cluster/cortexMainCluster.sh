#!/bin/bash
echo "
To install the cortex in the system please prepare the following requirement
1.ruler_storage & alertmanager_storage s3 buckets
2. blocks_storage s3 buckets "

# Install Prometheus with Helm chart
kubectl create namespace cortex
helm repo add stable https://charts.helm.sh/stable
helm repo update
helm install stable prometheus-community/kube-prometheus-stack 

# Verify Prometheus installation
kubectl get pods 
echo "Waiting for Prometheus pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=prom-app --timeout=3s

echo "Prometheus pod is up and running!"
echo "Prometheus installed on the Kind cluster using Helm chart!"

helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/consul
helm install consul hashicorp/consul --set global.name=consul --namespace cortex


# Source the env_variables.sh script to load the environment variables
echo "Applying envirnoment variable"
chmod +x env_variables.sh
. ./env_variables.sh
echo $ruler_BucketName

#Helper File to setup "files contains yaml"
echo "Applying Prometheus values "
chmod +x helper.sh
. ./helper.sh
