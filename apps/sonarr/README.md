# Sonarr on PiCluster

This directory contains Kubernetes manifests to deploy Sonarr (TV show PVR) on your PiCluster K3s setup, using a shared NFS PVC for downloads (integrated with Radarr and Transmission).

## Overview

Sonarr is a PVR for Usenet and BitTorrent users that automatically searches, downloads, and manages TV shows. This deployment includes:

- **Sonarr**: TV show management and automation
- **qBittorrent**: BitTorrent download client
- **Integrated storage**: Shares download folders and integrates with existing Jellyfin media

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (node03)
- Jellyfin already deployed (recommended)
- At least 1GB RAM available across worker nodes
- Valid indexers/trackers for content discovery

## Quick Start

1. **Deploy Sonarr:**
   ```bash
   cd apps/sonarr
   kubectl apply -f 01-storage.yaml
   kubectl apply -f 02-deployment.yaml
   kubectl apply -f 03-service.yaml
   ```

2. **Access Sonarr:**
   - Web interface: `http://192.168.88.163:30989`

3. **Complete initial setup (see Configuration section)**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories (only needed for config, not downloads)
ssh pi@node03 "sudo mkdir -p /mnt/storage/sonarr/config"
ssh pi@node03 "sudo chown -R 1000:1000 /mnt/storage/sonarr"

# Deploy manifests
kubectl apply -f 01-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Storage Structure

With the NFS Subdir External Provisioner, all downloads are stored in a shared directory on your NFS server. Sonarr, Radarr, and Transmission all use the same PVC (`shared-downloads-pvc` in the `downloads` namespace), which is mounted at `/downloads` in each pod.

```
/mnt/storage/
├── shared/
│   └── downloads/                 # Shared downloads directory (managed by provisioner)
│       ├── complete/
│       │   ├── tv-sonarr/         # Sonarr TV downloads (category)
│       │   └── radarr/            # Radarr movie downloads (category)
│       └── incomplete/
├── sonarr/
│   └── config/                    # Sonarr configuration and database
├── jellyfin/
│   └── media/
│       └── tv-shows/              # Final TV show destination (mounted in Sonarr as /tv)
```

**Note:**  
You do not need to manually create `/mnt/storage/sonarr/downloads/` or `/mnt/storage/shared/downloads/`. The provisioner manages the shared downloads directory automatically.

### Accessing Downloads

To check the shared downloads directory:
```bash
kubectl exec -n downloads deployment/sonarr -- ls -l /downloads/complete/
```
Or on the NFS server, look under `/mnt/storage/shared/downloads/complete/`.

## Configuration

### 1. Configure qBittorrent (First)

1. **Access qBittorrent:** `http://192.168.88.163:30080`
2. **Login with defaults:**
   - Username: `admin`
   - Password: `adminadmin`
3. **Change password immediately!**
4. **Configure download paths:**
   - Default Save Path: `/downloads` (shared NFS PVC)
   - Keep default category settings
5. **Configure connection settings:**
   - Port: `6881` (already configured)
   - Enable UPnP if needed

### 2. Configure Sonarr

1. **Access Sonarr:** `http://192.168.88.163:30989`
2. **Complete setup wizard**
3. **Add Download Client:**
   - Settings → Download Clients → Add qBittorrent
   - Host: `qbittorrent.qbittorrent.svc.cluster.local` (or the correct service name in your cluster)
   - Port: `8080`
   - Username: `admin`
   - Password: (your new password)
   - Category: `tv-sonarr` (optional)

4. **Configure Root Folders:**
   - Settings → Media Management → Root Folders
   - Add: `/tv` (this maps to your Jellyfin TV shows folder, which is `/mnt/storage/jellyfin/media/tv-shows/`)

5. **Add Indexers:**
   - Settings → Indexers
   - Add your preferred indexers/trackers
   - Configure API keys as needed

6. **Configure Quality Profiles:**
   - Adjust for Pi hardware limitations
   - Consider lower bitrates for better performance

## Integration with Jellyfin

The setup automatically integrates with your existing Jellyfin:

- Downloaded TV shows go to `/mnt/storage/jellyfin/media/tv-shows/`
- Jellyfin will automatically detect new episodes
- Use consistent naming conventions for best results
- All downloads are visible to Sonarr, Radarr, and Transmission instantly via the shared PVC

## Resource Configuration

**Sonarr:**
- Memory: 256Mi request, 1Gi limit
- CPU: 100m request, 500m limit
- Downloads: Shared NFS PVC (`shared-downloads-pvc`)

## ARM64 Optimizations

- Uses LinuxServer.io images with ARM64 support
- Conservative resource limits for Pi hardware
- Optimized for low-power operation
- Runs on worker nodes only

## Performance Tips

1. **Download Management:**
   - Limit concurrent downloads (2-3 max)
   - Use reasonable speed limits to avoid network saturation
   - Consider download scheduling during off-peak hours

2. **Storage Optimization:**
   - Monitor available space on NFS share (shared by Sonarr, Radarr, Transmission)
   - Configure automatic removal of completed downloads
   - Use quality profiles appropriate for Pi playback

3. **Indexer Configuration:**
   - Use reliable indexers with good API limits
   - Configure reasonable search intervals
   - Monitor failed downloads and adjust settings

## Troubleshooting

### Check pod status:
```bash
kubectl get pods -n downloads
kubectl describe pod <pod-name> -n downloads
kubectl logs -f deployment/sonarr -n downloads
```

### Common issues:

**Pods stuck in Pending:**
- Check if NFS directories exist with correct permissions
- Verify NFS server is running: `ssh pi@node03 "sudo systemctl status nfs-kernel-server"`

**Connection issues between Sonarr and qBittorrent:**
- Verify service names and ports
- Check network policies if any are configured
- Test connectivity: `kubectl exec -it deployment/sonarr -n sonarr -- ping qbittorrent.qbittorrent.svc.cluster.local`

**Download failures:**
- Check qBittorrent logs for connection issues
- Verify indexer credentials and API limits
- Monitor available storage space

**Slow downloads:**
- Check network bandwidth usage
- Adjust qBittorrent connection limits
- Verify Pi hardware isn't overloaded

### Access storage directly:
```bash
# On master node
ssh pi@node03
ls -la /mnt/storage/shared/downloads/complete/
ls -la /mnt/storage/jellyfin/media/tv-shows/
```

**Tip:**  
All downloads are now in `/mnt/storage/shared/downloads/` (shared by Sonarr, Radarr, Transmission).
```

## Security Considerations

- Change default qBittorrent password immediately
- Consider VPN integration for privacy
- Monitor resource usage to prevent abuse
- Use private indexers when possible
- Configure firewall rules as needed

## Advanced Configuration

### Adding VPN Support

For privacy, consider adding a VPN sidecar container:

```yaml
# Add to qbittorrent deployment
- name: vpn
  image: dperson/openvpn-client
  securityContext:
    capabilities:
      add: ["NET_ADMIN"]
  env:
  - name: VPN
    value: "path/to/vpn/config"
```

### Monitoring

Monitor download activity:
```bash
# Check download progress
kubectl exec -it deployment/qbittorrent -n qbittorrent -- ls -la /downloads/

# Monitor resource usage
kubectl top pods -n sonarr
kubectl top pods -n qbittorrent
```

## Scaling Considerations

This deployment uses single replicas for data consistency. For high availability:

1. Use ReadWriteMany storage for all volumes (already used for downloads via shared PVC)
2. Configure external databases
3. Implement proper session management
4. Consider active/passive failover

## Upgrading

To upgrade applications:
```bash
kubectl set image deployment/sonarr sonarr=linuxserver/sonarr:latest -n downloads
kubectl rollout status deployment/sonarr -n downloads
```

## Cleanup

To remove everything:
```bash
kubectl delete deployment sonarr -n downloads
# Manually remove NFS config directory if desired
ssh pi@node03 "sudo rm -rf /mnt/storage/sonarr"
```

## Useful Links

- [Sonarr Documentation](https://wiki.servarr.com/sonarr)
- [qBittorrent Documentation](https://github.com/qbittorrent/qBittorrent/wiki)
- [LinuxServer.io Docker Images](https://docs.linuxserver.io/)