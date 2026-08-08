# Nextcloud Deployment

Nextcloud deployment on Pi cluster with PostgreSQL and Redis. Remote access is via the Cloudflare Zero Trust Private Network Route (see `apps/cloudflare-tunnel/README.md`), not a per-app VPN sidecar.

## Prerequisites

1. PostgreSQL running in `database` namespace
2. NFS storage provisioner configured

## Deployment Steps

### 1. Update Secrets

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

- Service is `ClusterIP` only — not reachable from the LAN directly.
- Remote/local access is via WARP client + Cloudflare Zero Trust Private Network Route to the Service CIDR (`10.43.0.0/16`), connecting directly to the ClusterIP `10.43.27.203`. See `apps/cloudflare-tunnel/README.md`.
- Note: `*.svc.cluster.local` DNS does **not** work from client devices — `.local` is a reserved mDNS/Bonjour TLD, intercepted by the OS before any configured DNS server sees it. Use the ClusterIP directly.
- Admin user: `admin`
- Admin password: (as configured in deployment)

## Verification

```bash
# Check pod status
kubectl get pods -n nextcloud

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
