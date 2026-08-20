# Paperless-ngx

Paperless is deployed by Argo CD using the existing shared PostgreSQL and Redis services.

## One-time setup

Apply the namespace and PVCs first, then create the PostgreSQL role/database and Paperless secret. Do not commit either password.

```bash
kubectl apply -f apps/paperless/01-namespace-and-storage.yaml

export PAPERLESS_DB_PASSWORD="$(openssl rand -base64 32)"
kubectl exec -n database deploy/postgres -- sh -c \
  "psql -U \"\$POSTGRES_USER\" -d postgres -c \"CREATE USER paperless WITH PASSWORD '$PAPERLESS_DB_PASSWORD';\"" \
  || echo 'The paperless PostgreSQL role may already exist'
kubectl exec -n database deploy/postgres -- sh -c \
  'psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE paperless OWNER paperless;"' \
  || echo 'The paperless database may already exist'

kubectl create secret generic paperless-secret -n paperless \
  --from-literal=database-name=paperless \
  --from-literal=database-user=paperless \
  --from-literal=database-password="$PAPERLESS_DB_PASSWORD" \
  --from-literal=secret-key="$(openssl rand -base64 48)" \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 32)" \
  --from-literal=admin-mail=you@example.com
```

If the role/database already exists, recreate or update only the secret with the matching database password.

## Deploy

With Argo CD:

```bash
kubectl apply -f apps/argocd/paperless-application.yaml
kubectl get pods -n paperless -w
```

The hostname is `paperless.pfeiffer.pw`; configure that hostname in the existing Cloudflare Tunnel as an HTTP origin to:

```text
http://paperless-web.paperless.svc.cluster.local:8000
```

The application stores its 1Gi data directory and 10Gi document media directory on the cluster NFS storage class.
