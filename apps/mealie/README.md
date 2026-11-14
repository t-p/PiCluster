# Mealie

Self-hosted recipe manager using the shared PostgreSQL service.

## Database setup

Create the database and dedicated user using the PostgreSQL admin credentials. Generate a password first and keep it in the Kubernetes Secret:

```bash
MEALIE_DB_PASSWORD="$(openssl rand -hex 32)"
kubectl exec -n database deploy/postgres -- sh -c \
  "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -c \"CREATE USER mealie WITH PASSWORD '$MEALIE_DB_PASSWORD';\"" || true
kubectl exec -n database deploy/postgres -- sh -c \
  'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE DATABASE mealie OWNER mealie;"' || true
kubectl exec -n database deploy/postgres -- sh -c \
  'psql -U "$POSTGRES_USER" -d mealie -c "GRANT ALL ON SCHEMA public TO mealie;"'

kubectl create secret generic mealie-db-secret -n mealie \
  --from-literal=database-name=mealie \
  --from-literal=database-user=mealie \
  --from-literal=database-password="$MEALIE_DB_PASSWORD"
```

The `CREATE USER` and `CREATE DATABASE` commands are intentionally idempotent only by ignoring the already-exists error. Verify the resulting role/database if rerunning the commands.

## Deploy

After committing and pushing:

```bash
kubectl apply -f apps/argocd/mealie-application.yaml
```

The Cloudflare Tunnel must have a Published Application Route for `mealie.pfeiffer.pw` pointing to:

```text
http://mealie.mealie.svc.cluster.local:9000
```

On first login, Mealie uses its documented initial credentials:

```text
Email: changeme@example.com
Password: MyPassword
```

Change the password immediately. Keep `ALLOW_SIGNUP=false` after deployment.
