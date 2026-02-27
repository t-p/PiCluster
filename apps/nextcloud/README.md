# Nextcloud Deployment

Nextcloud deployment on Pi cluster with PostgreSQL, Redis, and Tailscale integration.

## Prerequisites

1. Tailscale auth key secret in the cluster
2. PostgreSQL running in `database` namespace
3. NFS storage provisioner configured

## Deployment Steps

### 1. Create Tailscale Auth Secret

If you don't already have the `tailscale-auth` secret in the nextcloud namespace:

```bash
kubectl create secret generic tailscale-auth \
  --from-literal=TS_AUTHKEY=tskey-auth-YOUR-KEY-HERE \
  --namespace=nextcloud
```

### 2. Update Secrets

Edit `02-database-init.yaml` and change:
- `CHANGE_ME_NEXTCLOUD_DB_PASSWORD` to a secure password

Edit `05-deployment.yaml` and change:
- `CHANGE_ME_ADMIN_PASSWORD` to a secure admin password

### 3. Apply Manifests

```bash
# Apply in order
kubectl apply -f 01-namespace-and-storage.yaml
kubectl apply -f 02-database-init.yaml
kubectl apply -f 03-redis.yaml
kubectl apply -f 04-tailscale-rbac.yaml
kubectl apply -f 05-deployment.yaml
kubectl apply -f 06-service.yaml
```

### 4. Wait for Database Initialization

```bash
kubectl wait --for=condition=complete job/nextcloud-db-init -n nextcloud --timeout=300s
```

### 5. Deploy via ArgoCD (Optional)

```bash
kubectl apply -f ../argocd/nextcloud-application.yaml
```

## Access

### Local Network
- URL: `http://192.168.88.X:30080` (any node IP)
- Admin user: `admin`
- Admin password: (as configured in deployment)

### Tailscale
1. Connect to your Tailscale network
2. Access via: `http://192.168.88.X:30080`
3. The Tailscale sidecar provides subnet routing for the 192.168.88.0/24 network

## Verification

```bash
# Check pod status
kubectl get pods -n nextcloud

# Check Tailscale connection
kubectl logs -n nextcloud deployment/nextcloud -c tailscale

# Check Nextcloud logs
kubectl logs -n nextcloud deployment/nextcloud -c nextcloud
```

## Troubleshooting

### Database Connection Issues
```bash
# Check database job logs
kubectl logs -n nextcloud job/nextcloud-db-init

# Verify database exists
kubectl exec -n database deployment/postgres -- psql -U postgres -c "\l"
```

### Tailscale Not Connecting
```bash
# Check Tailscale logs
kubectl logs -n nextcloud deployment/nextcloud -c tailscale

# Verify auth key is valid
kubectl get secret tailscale-auth -n nextcloud -o yaml
```

### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n nextcloud

# Check NFS provisioner
kubectl get pods -n default -l app=nfs-subdir-external-provisioner
```

## Configuration

### Trusted Domains
Add additional trusted domains by editing the `NEXTCLOUD_TRUSTED_DOMAINS` environment variable in `05-deployment.yaml`.

### Resource Limits
Adjust CPU and memory limits in `05-deployment.yaml` based on your usage.

## Maintenance

### Backup
Nextcloud data is stored on NFS at: `192.168.88.163:/mnt/storage/nextcloud-data-pvc-*`

### Updates
Update the image tag in `05-deployment.yaml` and apply:
```bash
kubectl apply -f 05-deployment.yaml
```

## References
- [Nextcloud Docker Hub](https://hub.docker.com/_/nextcloud)
- [Nextcloud Documentation](https://docs.nextcloud.com/)
