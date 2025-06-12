# Radarr on PiCluster

This directory contains Kubernetes manifests to deploy Radarr movie management server on your PiCluster K3s setup.

## Overview

Radarr is a movie collection manager for Usenet and BitTorrent users that automatically searches, downloads, and manages your movie collection. This deployment integrates seamlessly with your existing Jellyfin, Sonarr, qBittorrent, and Jackett setup.

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (192.168.88.163)
- qBittorrent or Transmission deployed (for downloading)
- Jackett or Prowlarr deployed (for indexers)
- Jellyfin deployed (for streaming)
- At least 1GB RAM available across worker nodes

## Quick Start

1. **Deploy Radarr:**
   ```bash
   cd apps/radarr
   kubectl apply -f 01-storage.yaml
   kubectl apply -f 02-deployment.yaml
   kubectl apply -f 03-service.yaml
   ```

2. **Access Radarr:**
   - Web interface: `http://192.168.88.162:30878` (or any node IP:30878)

3. **Complete setup and integration with existing stack**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories (only needed for config and media, not downloads)
ssh pi@192.168.88.163 "sudo mkdir -p /mnt/storage/radarr/config"
ssh pi@192.168.88.163 "sudo mkdir -p /mnt/storage/jellyfin/media/movies"
ssh pi@192.168.88.163 "sudo chown -R 1000:1000 /mnt/storage/radarr"
ssh pi@192.168.88.163 "sudo chown -R 1000:1000 /mnt/storage/jellyfin/media/movies"

# Deploy manifests
kubectl apply -f 01-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Storage Structure

All downloads are now stored in a shared NFS directory, used by Radarr, Sonarr, and Transmission via the `shared-downloads-pvc` in the `downloads` namespace. This PVC is mounted at `/downloads` in each pod.

```
/mnt/storage/
├── shared/
│   └── downloads/             # Shared downloads directory (managed by provisioner)
│       ├── complete/
│       │   ├── radarr/        # Radarr movie downloads (category)
│       │   └── tv-sonarr/     # Sonarr TV downloads (category)
│       └── incomplete/
├── radarr/
│   └── config/                # Radarr configuration and database
├── jellyfin/
│   └── media/
│       ├── movies/            # Final movie destination (mounted in Radarr as /movies)
│       └── tv-shows/          # TV shows from Sonarr
```

**Note:**  
You do not need to manually create `/mnt/storage/radarr/downloads/` or `/mnt/storage/sonarr/downloads/`. The NFS Subdir External Provisioner manages the shared downloads directory at `/mnt/storage/shared/downloads/` and dynamically creates subdirectories for each PVC.

### Accessing Downloads

To check the shared downloads directory:
```bash
kubectl exec -n downloads deployment/radarr -- ls -l /downloads/complete/
```
Or on the NFS server, look under `/mnt/storage/shared/downloads/complete/`.


## Configuration

### 1. Initial Setup

1. **Access Radarr:** `http://192.168.88.163:30878`
2. **Complete setup wizard**
3. **Configure authentication** (recommended)

### 2. Add Download Client (qBittorrent)

1. **Settings → Download Clients → Add qBittorrent**
2. **Configure:**
   - Name: `qBittorrent`
   - Host: `qbittorrent.qbittorrent.svc.cluster.local`
   - Port: `8080`
   - Username: `admin`
   - Password: (your qBittorrent password)
   - Category: `movies-radarr` (optional)
   - Use SSL: `No`

3. **Test connection**

### 3. Configure Root Folders

1. **Settings → Media Management → Root Folders**
2. **Add:** `/movies`
3. **This maps to:** `/mnt/storage/jellyfin/media/movies/`
   (Radarr's `/movies` mount in the pod)

### 4. Add Indexers from Jackett

1. **Settings → Indexers → Add Torznab**
2. **For each Jackett indexer:**
   - Name: `Jackett - [IndexerName]`
   - URL: `http://jackett.jackett.svc.cluster.local:9117/api/v2.0/indexers/INDEXER_ID/results/torznab/`
   - API Key: `fyo4419aqv41y5nq6at1tr7doz4yxz44`
   - Categories: `2000,2010,2020,2030,2040,2050,2060` (Movies)
   - Enable RSS Sync: ✅
   - Enable Automatic Search: ✅

3. **Test each indexer**

### 5. Quality Profiles

Configure quality profiles suitable for Pi hardware:
- **Any**: For maximum compatibility
- **HD-720p**: Good balance for Pi streaming
- **HD-1080p**: If you have good network/storage

## Movie Categories for Indexers

When configuring Jackett indexers in Radarr, use these categories:
```
2000    # Movies
2010    # Movies/Foreign
2020    # Movies/Other
2030    # Movies/SD
2040    # Movies/HD
2050    # Movies/BluRay
2060    # Movies/3D
```

## Integration with Existing Stack

### Complete Workflow:
```
Radarr searches → Jackett queries indexers → 
Results returned → Radarr picks quality → 
Sends to qBittorrent → Downloads to /downloads → 
Radarr moves to /movies → Jellyfin detects new movie
```

### Shared Resources:
- **Download Client**: Same qBittorrent instance as Sonarr
- **Indexers**: Same Jackett indexers (different categories)
- **Storage**: Shared NFS storage with different folders
- **Streaming**: Same Jellyfin instance

## Resource Configuration

- **Memory:** 256Mi request, 1Gi limit
- **CPU:** 100m request, 500m limit
- **Config:** 5Gi persistent storage
- **Downloads:** 200Gi (shared with Sonarr and Transmission via shared-downloads-pvc)
- **Movies:** 2Ti persistent storage

## ARM64 Optimizations

- Uses LinuxServer.io Radarr image with ARM64 support
- Conservative resource limits for Pi hardware
- Optimized for low-power operation
- Runs on nodes labeled as workers (see nodeSelector in deployment)

## Performance Tips

1. **Quality Management:**
   - Start with 720p or 1080p profiles
   - Avoid 4K content on Pi hardware
   - Use reasonable file size limits

2. **Download Management:**
   - Coordinate with Sonarr to avoid bandwidth conflicts
   - Use quality profiles to control file sizes
   - Monitor available storage space

3. **Search Configuration:**
   - Use reliable indexers with good movie catalogs
   - Configure reasonable search intervals
   - Monitor failed searches and adjust indexers

## Troubleshooting

### Check Radarr Status:
```bash
kubectl get pods -n downloads
kubectl logs -f deployment/radarr -n downloads
kubectl describe pod -n downloads -l app=radarr
```

### Common Issues:

**Pod not starting:**
- Check if NFS directories exist with correct permissions (for config and media)
- Verify NFS server is running on master node
- Check resource availability on worker nodes

**Can't connect to qBittorrent:**
- Verify qBittorrent is running: `kubectl get pods -n qbittorrent`
- Test internal connectivity: `kubectl exec -it deployment/radarr -n radarr -- ping qbittorrent.qbittorrent.svc.cluster.local`
- Check qBittorrent credentials in Radarr settings

**No search results:**
- Verify Jackett indexers are working
- Check movie categories in indexer configuration
- Monitor Jackett logs during searches: `kubectl logs -f deployment/jackett -n jackett`

**Downloads not moving to movies folder:**
- Check Radarr logs for move errors
- Verify permissions on movies directory
- Ensure sufficient space in movies folder

### Access Storage Directly:
```bash
# Check movies directory
ssh pi@192.168.88.163 "ls -la /mnt/storage/jellyfin/media/movies/"

# Check shared downloads directory
ssh pi@192.168.88.163 "ls -la /mnt/storage/shared/downloads/complete/radarr/"

# Check Radarr config
ssh pi@192.168.88.163 "ls -la /mnt/storage/radarr/config/"
```

## Movie Naming Convention

Radarr will organize movies using this structure:
```
/movies/
├── Movie Name (2023)/
│   └── Movie Name (2023) [Quality].mkv
├── Another Movie (2022)/
│   └── Another Movie (2022) [1080p].mp4
```

## Integration with Jellyfin

- Movies are automatically placed in `/mnt/storage/jellyfin/media/movies/`
- Jellyfin will detect new movies automatically
- Use proper naming for best metadata detection
- Force library scan in Jellyfin if movies don't appear immediately

## Security Considerations

- Set authentication in Radarr dashboard
- Use private indexers when possible
- Monitor resource usage to prevent abuse
- Consider VPN integration for additional privacy
- Regularly update Radarr and dependencies

## Monitoring

### Check Download Activity:
```bash
# Monitor Radarr logs
kubectl logs -f deployment/radarr -n radarr

# Check qBittorrent downloads
kubectl logs -f deployment/qbittorrent -n qbittorrent

# Monitor resource usage
kubectl top pods -n radarr
```

### Performance Metrics:
- Search success rates per indexer
- Download completion times
- Movie file sizes and quality
- Storage usage trends

## Upgrading

To upgrade Radarr:
```bash
kubectl set image deployment/radarr radarr=linuxserver/radarr:latest -n downloads
kubectl rollout status deployment/radarr -n downloads
```

## Scaling Considerations

This deployment uses a single replica for data consistency. For high availability:
1. Use ReadWriteMany storage for all volumes
2. Configure external database
3. Implement proper session management
4. Consider active/passive failover

## Cleanup

To remove Radarr:
```bash
kubectl delete deployment radarr -n downloads
kubectl delete svc radarr radarr-nodeport -n downloads
# Manually remove NFS directories if desired (config only; downloads are shared)
ssh pi@192.168.88.163 "sudo rm -rf /mnt/storage/radarr"
```

## Adding Movies

### Automatic (Recommended):
1. **Search for movie** in Radarr web interface
2. **Add to library** with desired quality profile
3. **Radarr automatically** searches, downloads, and organizes

### Manual:
1. **Add movie** to monitoring list
2. **Manual search** for specific releases
3. **Download** chosen release

## Popular Movie Indexers

When adding indexers through Jackett:
- **YTS** - High quality movies, smaller files
- **1337x** - General purpose, good movie selection  
- **RARBG** - High quality releases (if available)
- **TorrentLeech** - Private tracker, excellent quality
- **IPTorrents** - Private tracker, large selection

## Useful Links

- [Radarr Documentation](https://wiki.servarr.com/radarr)
- [LinuxServer.io Radarr](https://docs.linuxserver.io/images/docker-radarr)
- [Quality Profiles Guide](https://wiki.servarr.com/radarr/settings#quality-profiles)
- [Custom Formats](https://wiki.servarr.com/radarr/settings#custom-formats)