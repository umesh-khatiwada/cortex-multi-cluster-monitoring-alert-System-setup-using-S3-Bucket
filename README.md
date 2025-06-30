# Cortex Monitoring Setup

This repository contains automated bash scripts for setting up a complete Cortex monitoring infrastructure with Prometheus on Kubernetes. The setup includes a main cluster with Cortex and worker clusters that send metrics to the main cluster.

## Overview

The monitoring setup consists of:
- **Main Cluster**: Runs Cortex with Prometheus, Alertmanager, and Nginx for authentication
- **Worker Clusters**: Run Prometheus instances that forward metrics to the main cluster
- **S3 Storage**: Used for long-term storage of metrics, rules, and alerts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Worker Cluster │    │  Worker Cluster │    │  Worker Cluster │
│                 │    │                 │    │                 │
│   Prometheus    │    │   Prometheus    │    │   Prometheus    │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │         Remote Write │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     Main Cluster        │
                    │                         │
                    │  ┌─────────────────┐    │
                    │  │     Nginx       │    │
                    │  │ (Load Balancer) │    │
                    │  └─────────┬───────┘    │
                    │            │            │
                    │  ┌─────────▼───────┐    │
                    │  │     Cortex      │    │
                    │  │   - Distributor │    │
                    │  │   - Ingester    │    │
                    │  │   - Querier     │    │
                    │  │   - Ruler       │    │
                    │  │   - Alertmanager│    │
                    │  └─────────────────┘    │
                    │            │            │
                    │  ┌─────────▼───────┐    │
                    │  │   Prometheus    │    │
                    │  │  (Main Query)   │    │
                    │  └─────────────────┘    │
                    └─────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │     AWS S3 Storage      │
                    │                         │
                    │ - Metrics (blocks)      │
                    │ - Rules                 │
                    │ - Alertmanager config   │
                    └─────────────────────────┘
```

## Prerequisites

### Software Requirements
- Kubernetes cluster (using Kind or any K8s cluster)
- Helm 3.x
- kubectl
- Docker (for Kind clusters)

### AWS Requirements
- AWS S3 buckets for storage:
  - **Ruler/Alertmanager Storage Bucket**: For storing rules and alertmanager configuration
  - **Blocks Storage Bucket**: For storing metric data
- AWS IAM user with S3 access permissions
- AWS Access Key ID and Secret Access Key

### Default Credentials
- **Nginx Basic Auth**: 
  - Username: `openuser`
  - Password: `openuser`

## File Structure

```
bash_monitoring/
├── main_cluster/
│   ├── cortexMainCluster.sh    # Main deployment script
│   ├── env_variables.sh        # Environment variables and S3 configuration
│   └── helper.sh              # Kubernetes manifests and Helm configurations
└── worker_clusters/
    └── workerCluster.sh       # Worker cluster setup script
```

## Setup Instructions

### 1. Main Cluster Setup

#### Step 1: Configure Environment Variables

Edit `main_cluster/env_variables.sh` and update the following variables with your AWS S3 configuration:

```bash
# S3 ruler_storage & alertmanager storage
ruler_BucketName=your-cortex-ruler-alertmanager-storage
ruler_AccessKeyId=YOUR_AWS_ACCESS_KEY_ID
ruler_SecretAccessKey=YOUR_AWS_SECRET_ACCESS_KEY
ruler_Endpoint=s3.your-region.amazonaws.com
ruler_Region=your-aws-region

# S3 blocks_storage
blocks_BucketName=your-cortex-prometheus-storage
blocks_AccessKeyId=YOUR_AWS_ACCESS_KEY_ID
blocks_SecretAccessKey=YOUR_AWS_SECRET_ACCESS_KEY
blocks_Endpoint=s3.your-region.amazonaws.com
blocks_Region=your-aws-region
```

#### Step 2: Deploy Main Cluster

```bash
cd main_cluster
chmod +x cortexMainCluster.sh
./cortexMainCluster.sh
```

This script will:
1. Create the `cortex` namespace
2. Install kube-prometheus-stack
3. Install Consul for service discovery
4. Deploy Cortex with all components
5. Configure Nginx with basic authentication
6. Set up Prometheus for monitoring

#### Step 3: Verify Installation

```bash
# Check if all pods are running
kubectl get pods -n cortex

# Check services
kubectl get svc -n cortex

# Get the Nginx LoadBalancer IP
kubectl get svc cortex-nginx -n cortex
```

### 2. Worker Cluster Setup

#### Step 1: Deploy Worker Cluster

```bash
cd worker_clusters
chmod +x workerCluster.sh
./workerCluster.sh
```

#### Step 2: Configure Remote Write

When prompted, provide:
- **Cortex-nginx IP or Domain**: The external IP or domain of your main cluster's Nginx service
- **Basic Auth Credentials**: Username and password for authentication

Example:
```
Enter Cortex-nginx IP or Domain: http://192.168.1.100
Enter Basic Auth username and password: openuser openuser
```

## Configuration Details

### Main Cluster Components

#### Cortex Configuration
- **Authentication**: Enabled with Nginx basic auth
- **Storage Backend**: AWS S3
- **Components**: All Cortex components (distributor, ingester, querier, ruler, alertmanager)
- **Monitoring**: ServiceMonitor enabled for all components

#### Nginx Configuration
- **Port**: 80
- **Load Balancer**: Enabled
- **Basic Auth**: Username/password authentication
- **Headers**: X-Scope-OrgID set to remote user

#### Prometheus Configuration
- **Remote Write**: Configured to send metrics to Cortex
- **Retention**: 10 days
- **RBAC**: Full cluster monitoring permissions

### Worker Cluster Components

#### Prometheus Configuration
- **Remote Write**: Sends all metrics to main cluster
- **Scraping**: Configured to scrape cluster metrics
- **Authentication**: Basic auth for remote write

## Accessing the Services

### Main Cluster Access

1. **Get Nginx Service IP**:
```bash
kubectl get svc cortex-nginx -n cortex
```

2. **Access Cortex API**:
```bash
curl -u openuser:openuser http://<NGINX_IP>/api/prom/query?query=up
```

3. **Access Prometheus**:
```bash
kubectl get svc prometheus-app
```

### Grafana Dashboards

If you have Grafana installed, you can import the following dashboards:
- Cortex Overview Dashboard
- Kubernetes Cluster Monitoring Dashboard
- Prometheus Stats Dashboard

## Troubleshooting

### Common Issues

#### 1. Pods Not Starting
```bash
# Check pod status
kubectl get pods -n cortex
kubectl describe pod <pod-name> -n cortex

# Check logs
kubectl logs <pod-name> -n cortex
```

#### 2. S3 Connection Issues
- Verify AWS credentials in `env_variables.sh`
- Check S3 bucket permissions
- Ensure buckets exist in the specified region

#### 3. Remote Write Failures
- Verify Nginx service is accessible
- Check basic auth credentials
- Ensure network connectivity between clusters

#### 4. Consul Connection Issues
```bash
# Check Consul pods
kubectl get pods -n cortex | grep consul

# Check Consul logs
kubectl logs -l app=consul -n cortex
```

### Useful Commands

```bash
# View Cortex configuration
kubectl get cm cortex -n cortex -o yaml

# Check Prometheus targets
curl -u openuser:openuser http://<NGINX_IP>/prometheus/api/v1/targets

# View metrics
curl -u openuser:openuser http://<NGINX_IP>/api/prom/query?query=cortex_ingester_samples_in_total

# Scale components
kubectl scale deployment cortex-distributor -n cortex --replicas=3
```

## Security Considerations

1. **Change Default Passwords**: Update the default basic auth credentials
2. **Network Policies**: Implement Kubernetes network policies
3. **TLS**: Configure TLS for production deployments
4. **IAM Permissions**: Use minimal required AWS permissions
5. **Secret Management**: Use Kubernetes secrets for sensitive data

## Monitoring and Alerting

### Key Metrics to Monitor

- `cortex_ingester_samples_in_total`: Ingestion rate
- `cortex_distributor_samples_in_total`: Distribution rate
- `cortex_query_frontend_queries_total`: Query rate
- `prometheus_remote_storage_samples_failed_total`: Remote write failures

### Alerting Rules

The setup includes basic alerting rules for:
- High ingestion latency
- Failed remote writes
- Component unavailability
- S3 storage issues

## Scaling

### Horizontal Scaling

```bash
# Scale distributors
kubectl scale deployment cortex-distributor -n cortex --replicas=3

# Scale ingesters
kubectl scale deployment cortex-ingester -n cortex --replicas=6

# Scale queriers
kubectl scale deployment cortex-querier -n cortex --replicas=2
```

### Vertical Scaling

Update resource requests and limits in the Helm values or deployment manifests.

## Maintenance

### Regular Tasks

1. **Monitor S3 costs**: Keep track of storage usage
2. **Update components**: Regularly update Helm charts
3. **Backup configurations**: Backup Kubernetes manifests
4. **Monitor performance**: Track query and ingestion performance

### Cleanup

```bash
# Remove worker cluster
helm uninstall prometheus-server
kind delete cluster --name monitoring

# Remove main cluster
helm uninstall cortex -n cortex
kubectl delete namespace cortex
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Cortex documentation: https://cortexmetrics.io/
3. Check Kubernetes and Helm documentation

## License

This project is part of Open Source Project.
