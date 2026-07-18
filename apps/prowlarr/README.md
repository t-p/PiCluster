# Prowlarr

Indexer manager and proxy for torrent trackers. Replaces Jackett. Syncs indexers automatically to Sonarr and Radarr.

- **Image**: `linuxserver/prowlarr:2.4.0`
- **Namespace**: `prowlarr`
- **Node**: `node06`

## Access

- `http://192.168.88.162:30996` (NodePort 30996)

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9696 | HTTP | Web UI / API |

## Storage

| Name | Type | Server | Path | Size |
|------|------|--------|------|------|
| `prowlarr-config-pvc` | NFS | 192.168.88.163 | `/mnt/storage/prowlarr/config` | 2Gi |

## Files

| File | Purpose |
|------|---------|
| `01-namespace-and-storage.yaml` | Namespace and PVC |
| `02-deployment.yaml` | Deployment |
| `03-service.yaml` | NodePort service |

## Integration

Prowlarr syncs configured indexers directly to Sonarr and Radarr via their APIs — no manual indexer configuration needed in each *arr app.
