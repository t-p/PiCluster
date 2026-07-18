# n8n

Self-hosted workflow automation platform. Connects apps and services via visual workflows.

- **Image**: `n8nio/n8n:2.30.7`
- **Namespace**: `automation`
- **Node**: `node06`
- **Docs**: https://docs.n8n.io

## Access

- `http://192.168.88.126:32000` (NodePort 32000)

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 5678 | HTTP | Web UI / API / Webhooks |

## Storage

| Name | Type | Server | Path | Size |
|------|------|--------|------|------|
| `n8n-data` | NFS | 192.168.88.163 | `/mnt/storage/n8n/` | 2Gi |

## Dependencies

- **PostgreSQL**: `postgres.database.svc.cluster.local:5432` (database: `n8n`)
- **Redis**: `redis.database.svc.cluster.local:6379` (db 2, for queue)

## Secrets

Two secrets must be created manually before deploying:

```bash
kubectl create secret generic n8n-secret -n automation \
  --from-literal=encryption-key="$(openssl rand -base64 32)" \
  --from-literal=webhook-url="http://192.168.88.126:32000" \
  --from-literal=db-password="your-postgres-password"

kubectl create secret generic n8n-aws-secret -n automation \
  --from-literal=aws-access-key-id="your-aws-access-key" \
  --from-literal=aws-secret-access-key="your-aws-secret-key" \
  --from-literal=aws-region="us-east-1"
```

## Files

| File | Purpose |
|------|---------|
| `01-namespace-and-storage.yaml` | Namespace and PVC |
| `02-secrets.yaml` | Secret templates (do not commit real values) |
| `03-deployment.yaml` | Deployment |
| `04-service.yaml` | NodePort service |
