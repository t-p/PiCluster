# Jellyseerr

Media request management UI for Jellyfin, Radarr, and Sonarr.

- **Image**: `fallenbagel/jellyseerr:1.14.0`
- **Namespace**: `jellyseerr`
- **Node**: `node06`
- **Docs**: https://docs.jellyseerr.dev

## Access

| Protocol | URL |
|----------|-----|
| HTTP | http://192.168.88.126:30055 |

## Ports

| Container | Service | NodePort |
|-----------|---------|----------|
| 5055 | 5055 | 30055 |

## Storage

| Name | Type | Server | Path | Size |
|------|------|--------|------|------|
| `jellyseerr-config-pvc` | NFS | 192.168.88.163 | `/mnt/storage/jellyseerr/config` | 250Mi |

## Files

```
apps/jellyseerr/
  01-namespace-and-storage.yaml
  02-deployment.yaml
  03-service.yaml
```
