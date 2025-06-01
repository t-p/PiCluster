# Kubernetes Dashboard on PiCluster

This directory contains setup files and scripts to deploy and configure the official Kubernetes Dashboard on your PiCluster K3s setup.

## Overview

The Kubernetes Dashboard is a web-based Kubernetes user interface that allows you to:
- Deploy containerized applications to a Kubernetes cluster
- Troubleshoot your containerized applications
- Manage cluster resources
- Get an overview of applications running on your cluster
- Create or modify individual Kubernetes resources

## Prerequisites

- PiCluster with K3s installed and running
- kubectl configured and working
- Admin access to the cluster
- Web browser with HTTPS support

## Quick Start

1. **Run the setup script:**
   ```bash
   cd apps/kubernetes-dashboard
   ./setup.sh
   ```

2. **Access the dashboard:**
   - URL: `https://192.168.88.163:30443`
   - Use the admin token provided by the setup script

3. **Login and explore your cluster!**

## Manual Setup

If you prefer manual setup:

### 1. Deploy Kubernetes Dashboard:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

### 2. Create Admin User:
```bash
kubectl apply -f 01-admin-user.yaml
```

### 3. Create NodePort Service:
```bash
kubectl apply -f 02-nodeport-service.yaml
```

### 4. Get Access Token:
```bash
kubectl -n kubernetes-dashboard create token admin-user
```

## Files Included

- **01-admin-user.yaml** - Creates admin ServiceAccount and ClusterRoleBinding
- **02-nodeport-service.yaml** - Exposes dashboard via NodePort (30443)
- **setup.sh** - Automated setup script
- **README.md** - This documentation

## Access Methods

### Method 1: NodePort (Recommended)
- **URL**: `https://192.168.88.163:30443`
- **Pros**: Direct access, works from any network location
- **Cons**: Uses self-signed certificate (browser warning)

### Method 2: kubectl proxy
```bash
kubectl proxy
```
Then visit: `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`

### Method 3: Port Forwarding
```bash
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
```
Then visit: `https://localhost:8443`

## Authentication

The setup creates an admin user with cluster-admin privileges. To get a new token:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

### Token Usage:
1. Copy the token from terminal
2. Go to dashboard login page
3. Select "Token" option
4. Paste token and click "Sign In"

## Dashboard Features

### Overview:
- **Cluster status** - Nodes, namespaces, persistent volumes
- **Workloads** - Deployments, pods, replica sets, daemon sets
- **Services** - Services, ingresses, network policies
- **Storage** - Persistent volumes, storage classes
- **Config** - Config maps, secrets

### Management:
- **Create resources** - Deploy applications via YAML or forms
- **Edit resources** - Modify existing deployments and services
- **Scale applications** - Increase/decrease replica counts
- **View logs** - Container and pod logs
- **Execute commands** - Shell access to containers

## Security Considerations

### Admin Access:
- The created admin-user has **full cluster access**
- Consider creating limited-access users for production
- Tokens have limited lifetime and need periodic renewal

### Network Security:
- Dashboard exposed on all node IPs via NodePort
- Uses self-signed certificates (browser warnings expected)
- Consider adding ingress with proper TLS for production

### Best Practices:
- **Change default passwords** in applications
- **Monitor access logs** for suspicious activity
- **Use RBAC** for granular permissions
- **Regular updates** of dashboard and cluster

## Troubleshooting

### Dashboard Not Accessible:
```bash
# Check pod status
kubectl get pods -n kubernetes-dashboard

# Check service
kubectl get svc -n kubernetes-dashboard

# Check logs
kubectl logs -n kubernetes-dashboard deployment/kubernetes-dashboard
```

### Token Issues:
```bash
# Create new token
kubectl -n kubernetes-dashboard create token admin-user

# Check admin user exists
kubectl get serviceaccount admin-user -n kubernetes-dashboard

# Check cluster role binding
kubectl get clusterrolebinding admin-user
```

### Browser Certificate Warnings:
- **Expected behavior** - Dashboard uses self-signed certificates
- **Safe to proceed** - Click "Advanced" → "Proceed to site"
- **Alternative** - Use kubectl proxy method for HTTP access

### Common Issues:

**"Forbidden" errors:**
- Token expired - generate new token
- Insufficient permissions - check RBAC bindings

**Can't reach dashboard:**
- Check NodePort service exists
- Verify firewall settings on nodes
- Test with kubectl proxy method

**Login loop:**
- Clear browser cache and cookies
- Try incognito/private browsing mode
- Verify token is copied correctly (no extra spaces)

## Monitoring Your Cluster

### Useful Dashboard Views:

**For Media Stack Monitoring:**
- **Workloads → Deployments** - Check jellyfin, sonarr, radarr status
- **Workloads → Pods** - View resource usage and restarts
- **Storage → Persistent Volumes** - Monitor storage usage
- **Network → Services** - Check service endpoints

**For Troubleshooting:**
- **Workloads → Pods → [pod-name] → Logs** - View application logs
- **Cluster → Events** - System-wide events and errors
- **Cluster → Nodes** - Node health and resource usage

## Customization

### Creating Limited Users:
Instead of cluster-admin, create users with specific permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: limited-user
  namespace: specific-namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view  # or edit, admin
subjects:
- kind: ServiceAccount
  name: limited-user
  namespace: kubernetes-dashboard
```

### Adding to Homer Dashboard:
Update your Homer configuration to include the dashboard:

```yaml
- name: "Kubernetes Dashboard"
  icon: "fas fa-dharmachakra"
  subtitle: "Cluster Management"
  tag: "admin"
  url: "https://192.168.88.163:30443"
  target: "_blank"
```

## Upgrading

To upgrade the dashboard:

```bash
# Apply latest version
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Check upgrade status
kubectl get pods -n kubernetes-dashboard

# May need to regenerate admin user
kubectl apply -f 01-admin-user.yaml
```

## Cleanup

To remove the Kubernetes Dashboard:

```bash
# Delete dashboard
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Delete admin user and NodePort
kubectl delete -f 01-admin-user.yaml
kubectl delete -f 02-nodeport-service.yaml
```

## Alternative Tools

If you prefer other Kubernetes management tools:

- **k9s** - Terminal-based cluster management
- **Lens** - Desktop Kubernetes IDE  
- **Portainer** - Container management platform
- **Octant** - Web-based cluster introspection (discontinued)

## Useful Links

- [Official Kubernetes Dashboard](https://github.com/kubernetes/dashboard)
- [Dashboard Documentation](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [K3s Documentation](https://docs.k3s.io/)