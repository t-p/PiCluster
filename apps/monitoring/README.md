# Kubernetes Monitoring Stack (Prometheus + Grafana)

This directory contains a minimal and expandable monitoring setup for your Kubernetes cluster using Prometheus and Grafana.

## Overview

The monitoring stack includes:
- **Prometheus**: Time-series database and metrics collection
- **Grafana**: Visualization and dashboarding tool
- **Node Exporter**: System metrics collector (runs on all nodes)
- **RBAC**: Proper role-based access control for Kubernetes integration

## Quick Start

1. **Deploy the monitoring namespace and RBAC:**
   ```bash
   kubectl apply -f 01-namespace-and-rbac.yaml
   ```

2. **Deploy Node Exporter (system metrics):**
   ```bash
   kubectl apply -f 02-node-exporter.yaml
   ```

3. **Deploy Prometheus:**
   ```bash
   kubectl apply -f 03-prometheus.yaml
   ```

4. **Deploy Grafana:**
   ```bash
   kubectl apply -f 04-grafana.yaml
   ```

5. **Access the services:**
   ```bash
   # Port forward Prometheus (http://localhost:9090)
   kubectl port-forward -n monitoring svc/prometheus 9090:9090

   # Port forward Grafana (http://localhost:3000)
   kubectl port-forward -n monitoring svc/grafana 3000:3000
   ```

## Default Credentials

- **Grafana**:
  - Username: `admin`
  - Password: `admin123`
  - ⚠️ **Change this password after first login!**

## Deployment Options

The deployment provides a clean installation without pre-configured dashboards:

### 🚀 Automated Deployment (Recommended)
```bash
./deploy.sh
```

### 📋 Manual Deployment
```bash
kubectl apply -f 01-namespace-and-rbac.yaml
kubectl apply -f 02-node-exporter.yaml
kubectl apply -f 03-prometheus.yaml
kubectl apply -f 04-grafana.yaml
```

This gives you:
- Clean Grafana installation (no dashboards)
- Prometheus datasource automatically configured
- Complete freedom to create your own dashboards
- Perfect for learning and customization

## What Gets Monitored

### Automatic Discovery
- **Kubernetes Nodes**: CPU, memory, disk, network metrics
- **Kubernetes Pods**: Any pod with `prometheus.io/scrape: "true"` annotation
- **System Metrics**: Via Node Exporter on all nodes

### Prometheus Targets
- `prometheus:9090` - Prometheus itself
- `node-exporter:9100` - System metrics from all nodes
- Kubernetes API server metrics
- Auto-discovered pods with scrape annotations

## Expanding the Setup

### Adding Custom Metrics

To make your application discoverable by Prometheus, add these annotations to your pod:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"        # Port where your /metrics endpoint is
    prometheus.io/path: "/metrics"    # Path to metrics (optional, defaults to /metrics)
```

### Adding Alert Rules (Optional)

Alert rules can be added later by updating the Prometheus ConfigMap in `03-prometheus.yaml`. This is optional and can be configured when needed.

### Adding Grafana Dashboards

#### Through Grafana UI (Recommended)
1. **Create Custom Dashboard:**
   - Go to Dashboards → New → New Dashboard
   - Add panels with Prometheus queries
   - Save your dashboard

2. **Import Community Dashboards:**
   - Go to Dashboards → New → Import
   - Popular dashboard IDs:
     - `1860` - Node Exporter Full
     - `6417` - Kubernetes Cluster Monitoring
     - `8588` - Kubernetes Deployment Statefulset Daemonset
     - `315` - Kubernetes cluster monitoring (via Prometheus)

#### Via ConfigMap (for automation)
1. Export dashboard JSON from Grafana UI
2. Create a ConfigMap with your dashboard JSON
3. Apply the ConfigMap and restart Grafana

### Persistent Storage

For production use, replace `emptyDir` volumes with persistent storage:

```yaml
# Example PersistentVolumeClaim for Prometheus
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Node Exporter │    │   Node Exporter │    │   Node Exporter │
│   (DaemonSet)   │    │   (DaemonSet)   │    │   (DaemonSet)   │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴───────────┐
                    │      Prometheus         │
                    │   (Scrapes Metrics)     │
                    └─────────────┬───────────┘
                                  │
                    ┌─────────────┴───────────┐
                    │       Grafana           │
                    │   (Visualizations)      │
                    └─────────────────────────┘
```

## Configuration Files

### Core Components
- `01-namespace-and-rbac.yaml` - Creates monitoring namespace and RBAC
- `02-node-exporter.yaml` - System metrics collector (DaemonSet)
- `03-prometheus.yaml` - Prometheus server with ConfigMap
- `04-grafana.yaml` - Grafana with persistent storage

### Key Configuration
- **Prometheus config**: Stored in ConfigMap in `03-prometheus.yaml`
- **Grafana datasources**: Auto-configured to use Prometheus in `04-grafana.yaml`
- **Retention**: Prometheus keeps 15 days of data by default

## Getting Started with Grafana

### First Time Setup
1. Access Grafana at http://localhost:3000
2. Login with `admin/admin123`
3. **Change your password immediately**
4. Prometheus datasource is already configured

### Creating Your First Dashboard
1. Go to **Dashboards → New → New Dashboard**
2. Click **Add visualization**
3. Select **Prometheus** as data source
4. Try these sample queries:
   - `up` - Shows which targets are up
   - `rate(node_cpu_seconds_total[5m])` - CPU usage rate
   - `node_memory_MemAvailable_bytes` - Available memory
   - `node_filesystem_free_bytes` - Free disk space

### Quick Dashboard Import
1. Go to **Dashboards → New → Import**
2. Enter dashboard ID `1860` (Node Exporter Full)
3. Click **Load** and **Import**
4. Enjoy instant system monitoring!

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n monitoring
```

### View Logs
```bash
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring daemonset/node-exporter
```

### Prometheus Targets
Check if targets are being discovered at: http://localhost:9090/targets

### Common Issues

1. **RBAC Permissions**: Ensure the ClusterRole and ClusterRoleBinding are applied
2. **Node Exporter Not Scraped**: Check if DaemonSet is running on all nodes
3. **Grafana Can't Connect**: Verify Prometheus service is accessible at `prometheus:9090`
4. **No Data in Grafana**: Check that Prometheus is scraping targets successfully
5. **Dashboard Import Fails**: Ensure the dashboard is compatible with your Prometheus version

## Security Considerations

- Change default Grafana password
- Consider using secrets for sensitive configuration
- Review RBAC permissions for production use
- Enable TLS for external access

## Production Enhancements

- Configure persistent storage for both Prometheus and Grafana
- Set up ingress controllers for external access
- Implement backup strategies for dashboards and configs
- Add resource limits and requests for all components
- Consider using Helm charts for easier management

## Scaling

The current setup is minimal but expandable:
- **Horizontal**: Add more Prometheus instances with federation
- **Vertical**: Increase storage and memory limits
- **Multi-cluster**: Use Prometheus federation or Thanos
- **High Availability**: Run multiple replicas with shared storage
