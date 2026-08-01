# Forgejo

Self-hosted Git forge — a community-driven fork of Gitea. Provides repositories, issues, pull requests, CI/CD (Forgejo Actions), and a full GitHub-like workflow on your own hardware.

- **Web UI**: http://forgejo.home or http://git.home
- **Direct HTTP**: http://<node-ip>:30030
- **SSH clone**: `git clone ssh://git@<node-ip>:30022/<user>/<repo>.git`
- **Namespace**: `forgejo`
- **Image**: `codeberg.org/forgejo/forgejo:16`
- **Storage**: 10Gi NFS PVC at `/data`
- **Database**: PostgreSQL (`forgejo` database on `postgres.database.svc.cluster.local`)

## Prerequisites

### 1. Create the PostgreSQL database and dedicated role

```bash
kubectl exec -n database deployment/postgres -- \
  psql -U postgres -c "CREATE DATABASE forgejo;"
kubectl exec -n database deployment/postgres -- \
  psql -U postgres -c "CREATE USER forgejo WITH ENCRYPTED PASSWORD 'your-generated-password';"
kubectl exec -n database deployment/postgres -- \
  psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;"
kubectl exec -n database deployment/postgres -- \
  psql -U postgres -d forgejo -c "ALTER DATABASE forgejo OWNER TO forgejo;"
```

Forgejo uses a **dedicated Postgres role**, not the shared `postgres` superuser — matching the pattern used by `immich`, `nextcloud`, and `stalwart` in this cluster.

### 2. Create the Kubernetes secret

```bash
kubectl create secret generic forgejo-secret -n forgejo \
  --from-literal=secret-key="$(openssl rand -hex 32)" \
  --from-literal=internal-token="$(openssl rand -hex 32)" \
  --from-literal=db-user="forgejo" \
  --from-literal=db-password="your-generated-password"
```

The `db-password` must match the password set for the dedicated `forgejo` role above.

## Deployment

```bash
# Deploy via ArgoCD (GitOps — preferred)
kubectl apply -f apps/argocd/forgejo-application.yaml

# Manual apply (development only)
kubectl apply -f apps/forgejo/
```

## First Login

After the pod is Running, open http://forgejo.home in a browser.

The install wizard is skipped (`INSTALL_LOCK=true`). Register the first user — Forgejo automatically promotes the first registered account to site administrator.

After creating your admin account, consider locking registration:

```bash
kubectl set env deployment/forgejo -n forgejo \
  FORGEJO__service__DISABLE_REGISTRATION=true
```

## Configuration

All settings are passed as environment variables using Forgejo's `FORGEJO__<section>__<key>` pattern. Edit `02-deployment.yaml` to change them.

| Variable | Default | Notes |
|---|---|---|
| `FORGEJO__server__DOMAIN` | `forgejo.home` | External hostname |
| `FORGEJO__server__ROOT_URL` | `http://forgejo.home` | Full URL |
| `FORGEJO__server__SSH_PORT` | `30022` | NodePort for SSH |
| `FORGEJO__service__DISABLE_REGISTRATION` | `false` | Lock after admin setup |
| `FORGEJO__mailer__ENABLED` | `false` | Enable for email notifications |

## Storage

| Path | Purpose |
|---|---|
| `/data/forgejo/conf/app.ini` | Generated config (managed by Forgejo) |
| `/data/forgejo/repositories` | Git repositories |
| `/data/forgejo/data` | Attachments, avatars, packages |
| `/data/git` | Git home directory |

## Ports

| Service | Type | Port | Purpose |
|---|---|---|---|
| `forgejo` | ClusterIP | 3000 | Internal HTTP (used by Ingress) |
| `forgejo-nodeport` | NodePort | 30030 | Direct HTTP access |
| `forgejo-ssh` | NodePort | 30022 | SSH git operations |

## Troubleshooting

```bash
# Check pod status
kubectl get pods -n forgejo

# View logs
kubectl logs -n forgejo deployment/forgejo

# Shell into pod
kubectl exec -it -n forgejo deployment/forgejo -- sh

# Check database connectivity
kubectl exec -n forgejo deployment/forgejo -- \
  forgejo admin user list
```
