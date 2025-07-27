# Homarr Dashboard

Homarr is a modern dashboard for your homelab services, providing a clean interface to access all your applications.

## Overview

- **Namespace**: `dashboard`
- **Image**: `ghcr.io/homarr-labs/homarr:v1.30.0`
- **Access**: NodePort 31880 (http://NODE_IP:31880)
- **Storage**: 250Mi NFS persistent volume
- **Database**: SQLite

## Components

### 01-namespace-and-storage.yaml
- Creates `dashboard` namespace
- Creates `homarr-database` PVC (250Mi NFS storage)
- **Note**: `db-secret` must be created manually (see Deployment section)

### 02-deployment.yaml
- Homarr deployment with proper environment variables
- Service configuration (NodePort 31880 → 7575)
- Resource limits: 1000m CPU, 2Gi memory
- Resource requests: 200m CPU, 512Mi memory
- Node selector: Runs on node05

## Configuration

### Deployment Configuration
- **Node Affinity**: Deployed specifically on node05 (192.168.88.126)
- **Replicas**: 1 (single instance)
- **Strategy**: RollingUpdate with 25% surge/unavailable
- **WebSocket Support**: Enabled for real-time dashboard updates

### Key Environment Variables
- `TZ`: Timezone (UTC)
- `DB_URL`: SQLite database path (/appdata/db.sqlite)
- `SECRET_ENCRYPTION_KEY`: Database encryption key (from secret)
- `NODE_ENV`: production
- `NEXTJS_DISABLE_ESLINT`: true
- `REDIS_URL`: redis://localhost:6379
- `WEBSOCKET_URL`: ws://192.168.88.126:31881
- `WEBSOCKET_PORT`: 3001
- `NEXT_PUBLIC_WEBSOCKET_URL`: ws://192.168.88.126:31881

### Port Configuration
- **HTTP Port**: 3000 (Homarr web interface)
- **WebSocket Port**: 3001 (real-time updates)
- **Service Port**: 7575 (internal service port)
- **NodePort**: 31880 (external access)

## Access URLs

### Web Interface
You can access Homarr through any cluster node:
- http://192.168.88.167:31880 (node01)
- http://192.168.88.164:31880 (node02)
- http://192.168.88.163:31880 (node03)
- http://192.168.88.162:31880 (node04)
- http://192.168.88.126:31880 (node05) - **Primary node**

### WebSocket Connection
- **WebSocket URL**: ws://192.168.88.126:31881
- **Purpose**: Real-time dashboard updates and notifications
- **Note**: WebSocket connects specifically to node05 where the pod runs

## Deployment

### Step 1: Create the Secret (Required)
**⚠️ SECURITY: Never commit secrets to Git!**

Create the encryption key secret manually:

```bash
# Generate a secure 64-character hex key
ENCRYPTION_KEY=$(openssl rand -hex 32)

# Create the secret
kubectl create secret generic db-secret \
  --namespace=dashboard \
  --from-literal=db-encryption-key="$ENCRYPTION_KEY"

# Verify secret creation
kubectl get secret db-secret -n dashboard
```

**Alternative: Use existing key**
If you need to use a specific key (e.g., restoring from backup):
```bash
kubectl create secret generic db-secret \
  --namespace=dashboard \
  --from-literal=db-encryption-key="YOUR_64_CHAR_HEX_KEY_HERE"
```

### Step 2: Deploy Homarr
```bash
# Deploy namespace and storage
kubectl apply -f apps/homarr/01-namespace-and-storage.yaml

# Deploy application
kubectl apply -f apps/homarr/02-deployment.yaml

# Check status
kubectl get pods -n dashboard
kubectl get svc -n dashboard

# View logs
kubectl logs -n dashboard deployment/homarr
```

## Configuration Tips

### Adding Services to Dashboard
Once Homarr is running, you can add tiles for your other services:

- **Jellyfin**: `http://192.168.88.126:8096`
- **Radarr**: `http://192.168.88.162:7878`
- **Sonarr**: `http://192.168.88.162:8989`
- **Transmission**: `http://192.168.88.162:9091`
- **Prowlarr**: `http://192.168.88.162:9117`
- **Grafana**: `http://192.168.88.126:30300`
- **ArgoCD**: `http://192.168.88.163:30080`

### First Time Setup
1. Access Homarr at http://NODE_IP:31880
2. Create admin account
3. Configure dashboard layout
4. Add service tiles
5. Customize themes and settings

## Troubleshooting

### Common Issues
1. **500 Internal Server Error**: Usually missing SECRET_ENCRYPTION_KEY
2. **Connection refused**: Check if pod is running and service is configured
3. **Pending pod**: Check if PVC is bound and storage is available
4. **WebSocket connection issues**: Real-time updates not working
   - Check if WebSocket service exists for port 31881
   - Verify WebSocket port 3001 is accessible on the pod
   - Consider adding WebSocket NodePort service if missing

### Useful Commands
```bash
# Check pod status
kubectl describe pod -n dashboard -l app.kubernetes.io/name=homarr

# Check logs
kubectl logs -n dashboard -l app.kubernetes.io/name=homarr

# Check service
kubectl get svc -n dashboard homarr

# Test internal connectivity
kubectl exec -n dashboard deployment/homarr -- curl -s http://localhost:3000
```

## Security Notes

### 🔐 Critical Security Requirements

**⚠️ NEVER commit secrets to Git repositories!**

- **Database encryption key**: Must be created manually using `kubectl create secret`
- **Key rotation**: Regularly rotate encryption keys in production environments
- **Access control**: Limit who can access the `dashboard` namespace
- **HTTPS**: Consider using ingress with TLS certificates for production
- **Network policies**: Restrict pod-to-pod communication as needed
- **Backup security**: Ensure database backups are also encrypted

### Secret Management Best Practices

1. **Generate unique keys**: Use `openssl rand -hex 32` for cryptographically secure keys
2. **Environment separation**: Use different keys for dev/staging/production
3. **Key storage**: Consider using external secret management (Vault, AWS Secrets Manager, etc.)
4. **Audit access**: Monitor who accesses secrets and when
5. **Principle of least privilege**: Only grant necessary permissions

### If Secret is Compromised

If you accidentally committed a secret to Git:

```bash
# 1. Generate new key immediately
NEW_KEY=$(openssl rand -hex 32)

# 2. Update the secret
kubectl patch secret db-secret -n dashboard \
  --type='json' \
  -p='[{"op": "replace", "path": "/data/db-encryption-key", "value":"'$(echo -n "$NEW_KEY" | base64)'"}]'

# 3. Restart Homarr to use new key
kubectl rollout restart deployment/homarr -n dashboard

# 4. Remove from Git history (if needed)
# Consider using tools like git-filter-repo or BFG Repo-Cleaner
```

## Storage

- Uses NFS storage class for persistent data
- Database and configuration stored in `/appdata`
- 250Mi should be sufficient for most setups
- Increase storage if you have many custom icons/themes