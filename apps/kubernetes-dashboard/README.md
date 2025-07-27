# Kubernetes Dashboard

Web-based Kubernetes user interface for cluster management and monitoring.

## Overview

The Kubernetes Dashboard is a general-purpose, web-based UI for Kubernetes clusters. It provides a comprehensive interface for managing and monitoring your cluster resources, applications, and workloads through an intuitive web interface.

## Features

- **Cluster Overview**: Real-time cluster status, nodes, and resource utilization
- **Workload Management**: Deploy, scale, and manage applications and services
- **Resource Monitoring**: View pods, deployments, services, and storage resources
- **Log Viewing**: Access container and pod logs directly from the interface
- **YAML Editor**: Create and edit Kubernetes resources with built-in validation
- **Shell Access**: Execute commands in containers via web terminal
- **RBAC Integration**: Role-based access control with token authentication
- **Multi-Namespace**: Manage resources across all cluster namespaces
- **Real-time Updates**: Live updates of resource states and metrics

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │───▶│   NodePort      │───▶│   Dashboard     │
│   (HTTPS)       │    │   (30443)       │    │   Pod           │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │   Kubernetes    │
                                               │   API Server    │
                                               └─────────────────┘
```

## Components

### Core Application
- **Deployment**: Official Kubernetes Dashboard v2.7.0
- **Image**: `kubernetesui/dashboard:v2.7.0`
- **Namespace**: `kubernetes-dashboard`
- **Resources**: Managed by upstream deployment
- **Security**: HTTPS with self-signed certificates

### Authentication
- **Service Account**: `admin-user` with cluster-admin privileges
- **Authentication Method**: Bearer token authentication
- **Token Lifetime**: 1 hour (renewable)
- **RBAC**: Full cluster access via ClusterRoleBinding

### Network Services
- **Internal Service**: ClusterIP on port 443 (HTTPS)
- **External Service**: NodePort 30443 for external access
- **Protocol**: HTTPS only (TLS required)
- **Access**: Available on all cluster node IPs

## Deployment

### Prerequisites
- Kubernetes cluster (K3s) running
- kubectl configured with admin access
- Web browser with HTTPS support
- Network access to cluster nodes on port 30443

### Quick Start

```bash
# Deploy Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create admin user and NodePort service
kubectl apply -f apps/kubernetes-dashboard/01-admin-user.yaml
kubectl apply -f apps/kubernetes-dashboard/02-nodeport-service.yaml

# Get access token
kubectl -n kubernetes-dashboard create token admin-user

# Check deployment status
kubectl get pods -n kubernetes-dashboard
```

### Configuration Files

| File | Purpose |
|------|---------|
| `01-admin-user.yaml` | ServiceAccount and ClusterRoleBinding for admin access |
| `02-nodeport-service.yaml` | NodePort service for external access on port 30443 |

## Access

### Web Interface
- **URL**: `https://192.168.88.163:30443`
- **Alternative URLs**: Available on all cluster node IPs
- **Protocol**: HTTPS only (self-signed certificate)
- **Authentication**: Bearer token required

### Authentication Process
1. **Generate Token**:
   ```bash
   kubectl -n kubernetes-dashboard create token admin-user
   ```

2. **Access Dashboard**: Navigate to `https://192.168.88.163:30443`

3. **Login**: Select "Token" option and paste the generated token

4. **Accept Certificate**: Click "Advanced" → "Proceed to site" for self-signed cert

### Alternative Access Methods

#### kubectl proxy (HTTP)
```bash
kubectl proxy
# Access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

#### Port Forwarding
```bash
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
# Access: https://localhost:8443
```

## Monitoring

### Health Checks
- **Dashboard Pod**: Automatic liveness and readiness probes
- **Service Status**: NodePort service health monitoring
- **Token Validity**: 1-hour token expiration with renewal required

### Dashboard Sections

#### Cluster Overview
- **Nodes**: Node status, capacity, and resource usage
- **Namespaces**: All cluster namespaces and resource counts
- **Persistent Volumes**: Storage resources and claims
- **Events**: Cluster-wide events and alerts

#### Workloads
- **Deployments**: Application deployments and scaling
- **Pods**: Individual pod status, logs, and metrics
- **Replica Sets**: Replica set management and history
- **Daemon Sets**: Node-level service deployments
- **Jobs**: Batch jobs and cron jobs
- **Stateful Sets**: Stateful application management

#### Services & Discovery
- **Services**: Service endpoints and load balancing
- **Ingresses**: External access routing rules
- **Network Policies**: Traffic control and security

#### Storage
- **Persistent Volumes**: Cluster storage resources
- **Persistent Volume Claims**: Storage requests and bindings
- **Storage Classes**: Dynamic provisioning configurations

#### Configuration
- **Config Maps**: Application configuration data
- **Secrets**: Sensitive data and credentials
- **Resource Quotas**: Namespace resource limits

## Testing

### Dashboard Accessibility
```bash
# Check dashboard pod status
kubectl get pods -n kubernetes-dashboard -l k8s-app=kubernetes-dashboard

# Test NodePort service
kubectl get service kubernetes-dashboard-nodeport -n kubernetes-dashboard

# Verify service endpoints
kubectl get endpoints -n kubernetes-dashboard
```

### Authentication Testing
```bash
# Generate test token
kubectl -n kubernetes-dashboard create token admin-user

# Test token validity (should return user info)
kubectl auth whoami --token="<your-token>"

# Test cluster access with token
kubectl get nodes --token="<your-token>"
```

### Functionality Testing
```bash
# Test from within cluster
kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -qO- https://kubernetes-dashboard.kubernetes-dashboard.svc.cluster.local

# Test external access
curl -k -I https://192.168.88.163:30443
```

## Troubleshooting

### Common Issues

#### Dashboard Not Accessible
```bash
# Check all dashboard resources
kubectl get all -n kubernetes-dashboard

# Check pod logs
kubectl logs -n kubernetes-dashboard deployment/kubernetes-dashboard

# Check service endpoints
kubectl get endpoints -n kubernetes-dashboard

# Test internal connectivity
kubectl run debug --image=busybox --rm -it --restart=Never -- wget -qO- https://kubernetes-dashboard.kubernetes-dashboard.svc.cluster.local
```

#### Authentication Problems
```bash
# Generate new token
kubectl -n kubernetes-dashboard create token admin-user

# Verify admin user exists
kubectl get serviceaccount admin-user -n kubernetes-dashboard

# Check cluster role binding
kubectl get clusterrolebinding admin-user

# Test token permissions
kubectl auth can-i '*' '*' --token="<your-token>"
```

#### Certificate Issues
```bash
# Check certificate details
openssl s_client -connect 192.168.88.163:30443 -servername kubernetes-dashboard

# Alternative HTTP access via proxy
kubectl proxy --port=8001
# Then access: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

#### Network Connectivity
```bash
# Check NodePort service
kubectl get service kubernetes-dashboard-nodeport -n kubernetes-dashboard -o wide

# Test port accessibility
telnet 192.168.88.163 30443

# Check firewall rules (if applicable)
sudo ufw status
```

### Error Solutions

#### "Forbidden" or "Unauthorized" Errors
- **Cause**: Expired or invalid token
- **Solution**: Generate new token with `kubectl -n kubernetes-dashboard create token admin-user`

#### "This site can't be reached"
- **Cause**: Network connectivity or service issues
- **Solution**: Check NodePort service and node accessibility

#### Login Loop or Blank Page
- **Cause**: Browser cache or cookie issues
- **Solution**: Clear browser data or use incognito mode

#### "Internal error occurred"
- **Cause**: Dashboard pod issues or API server problems
- **Solution**: Check pod logs and restart if necessary

## Configuration

### Environment Variables
Dashboard configuration is managed by the upstream deployment:

- **Namespace**: `kubernetes-dashboard`
- **Service Account**: Uses default dashboard service account + admin-user
- **TLS**: Auto-generated self-signed certificates
- **Port**: Internal 8443, external 30443

### Admin User Configuration
The admin user is configured with cluster-admin privileges:

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

# ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

### NodePort Service Configuration
External access is provided via NodePort service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard-nodeport
  namespace: kubernetes-dashboard
spec:
  type: NodePort
  ports:
  - port: 443
    targetPort: 8443
    nodePort: 30443
    protocol: TCP
  selector:
    k8s-app: kubernetes-dashboard
```

## Security

### Access Control
- **Authentication**: Bearer token authentication required
- **Authorization**: RBAC-based permissions via ClusterRoleBinding
- **Network**: HTTPS-only access with self-signed certificates
- **Scope**: admin-user has full cluster-admin privileges

### Security Considerations
- **Token Management**: Tokens expire after 1 hour and must be regenerated
- **Certificate Warnings**: Self-signed certificates trigger browser warnings (expected)
- **Network Exposure**: Dashboard accessible on all node IPs via NodePort
- **Admin Privileges**: Current setup provides full cluster access

### Best Practices
- **Limited Users**: Create role-specific users instead of cluster-admin for production
- **Token Rotation**: Regularly regenerate access tokens
- **Network Policies**: Consider implementing network policies for additional security
- **TLS Certificates**: Use proper TLS certificates for production deployments

### Creating Limited Access Users
```yaml
# Read-only user example
apiVersion: v1
kind: ServiceAccount
metadata:
  name: readonly-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: readonly-user
  namespace: kubernetes-dashboard
```

## Maintenance

### Token Management
```bash
# Generate new admin token
kubectl -n kubernetes-dashboard create token admin-user

# Create long-lived token (not recommended for production)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF

# Get long-lived token
kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d
```

### Upgrading Dashboard
```bash
# Check current version
kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.template.spec.containers[0].image}'

# Upgrade to latest version
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Verify upgrade
kubectl get pods -n kubernetes-dashboard
kubectl rollout status deployment/kubernetes-dashboard -n kubernetes-dashboard

# Reapply custom configurations
kubectl apply -f apps/kubernetes-dashboard/01-admin-user.yaml
kubectl apply -f apps/kubernetes-dashboard/02-nodeport-service.yaml
```

### Backup & Recovery
```bash
# Backup dashboard configuration
kubectl get all,secrets,configmaps -n kubernetes-dashboard -o yaml > dashboard-backup.yaml

# Backup admin user configuration
kubectl get serviceaccount,clusterrolebinding admin-user -o yaml > admin-user-backup.yaml

# Restore from backup
kubectl apply -f dashboard-backup.yaml
kubectl apply -f admin-user-backup.yaml
```

## Performance

### Resource Usage
- **CPU**: ~10-50m under normal load
- **Memory**: ~50-100Mi typical usage
- **Storage**: Minimal (configuration only)
- **Network**: Low bandwidth usage

### Scaling Considerations
- Single instance sufficient for most use cases
- Dashboard is stateless and can be scaled horizontally if needed
- Performance depends on cluster size and API server responsiveness

## Integration

### Homarr Dashboard Integration
Add to your Homarr configuration:

```yaml
- name: "Kubernetes Dashboard"
  icon: "fas fa-dharmachakra"
  subtitle: "Cluster Management"
  tag: "admin"
  url: "https://192.168.88.163:30443"
  target: "_blank"
```

### Monitoring Integration
- **Prometheus**: Dashboard metrics available via Kubernetes API
- **Grafana**: Create dashboards using Kubernetes data sources
- **Alerting**: Set up alerts for dashboard availability

### Useful Dashboard Views for Your Cluster

#### Media Stack Monitoring
- **Workloads → Deployments**: Check Jellyfin, Sonarr, Radarr status
- **Workloads → Pods**: View resource usage and restart counts
- **Storage → Persistent Volumes**: Monitor NFS storage usage
- **Services & Discovery → Services**: Check service endpoints

#### Infrastructure Monitoring
- **Cluster → Nodes**: Node health and resource utilization
- **Cluster → Events**: System-wide events and alerts
- **Config and Storage → Persistent Volumes**: Storage capacity and claims
- **Workloads → Daemon Sets**: System services like MetalLB

## Cleanup

### Complete Removal
```bash
# Remove dashboard deployment
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Remove custom configurations
kubectl delete -f apps/kubernetes-dashboard/01-admin-user.yaml
kubectl delete -f apps/kubernetes-dashboard/02-nodeport-service.yaml

# Verify cleanup
kubectl get all -n kubernetes-dashboard
```

### Partial Cleanup (Keep Dashboard, Remove Admin User)
```bash
# Remove admin user only
kubectl delete -f apps/kubernetes-dashboard/01-admin-user.yaml
kubectl delete service kubernetes-dashboard-nodeport -n kubernetes-dashboard
```

## Alternative Tools

### Command Line Tools
- **k9s**: Terminal-based cluster management with real-time updates
- **kubectl**: Native Kubernetes CLI with extensive functionality
- **kubectx/kubens**: Context and namespace switching utilities

### Desktop Applications
- **Lens**: Kubernetes IDE with advanced features and extensions
- **Portainer**: Container management platform with Kubernetes support
- **Rancher Desktop**: Local Kubernetes development environment

### Web-based Alternatives
- **Rancher**: Enterprise Kubernetes management platform
- **OpenShift Console**: Red Hat's Kubernetes management interface
- **Kubeapps**: Application marketplace and management

---

**The Kubernetes Dashboard provides comprehensive web-based cluster management with full administrative access to your K3s cluster.**