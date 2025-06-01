# Sonarr on PiCluster

This directory contains Kubernetes manifests to deploy Sonarr (TV show PVR) along with qBittorrent (download client) on your PiCluster K3s setup.

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

1. **Deploy both Sonarr and qBittorrent:**
   ```bash
   cd apps/sonarr
   ./deploy.sh
   ```

2. **Access the applications:**
   - Sonarr: `http://192.168.88.163:30989`
   - qBittorrent: `http://192.168.88.163:30080`

3. **Complete initial setup (see Configuration section)**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories
ssh pi@node03 "sudo mkdir -p /mnt/storage/sonarr/{config,downloads}"
ssh pi@node03 "sudo mkdir -p /mnt/storage/qbittorrent/config"
ssh pi@node03 "sudo chown -R 1000:1000 /mnt/storage/{sonarr,qbittorrent}"

# Deploy Sonarr
kubectl apply -f 01-namespace-and-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml

# Deploy qBittorrent
kubectl apply -f ../qbittorrent/01-namespace-and-storage.yaml
kubectl apply -f ../qbittorrent/02-deployment.yaml
kubectl apply -f ../qbittorrent/03-service.yaml
```

## Storage Structure

```
/mnt/storage/
├── sonarr/
│   ├── config/          # Sonarr configuration and database
│   └── downloads/       # Shared download directory
├── qbittorrent/
│   └── config/          # qBittorrent configuration
└── jellyfin/
    └── media/
        └── tv-shows/    # Final TV show destination (mounted in Sonarr as /tv)
```

## Configuration

### 1. Configure qBittorrent (First)

1. **Access qBittorrent:** `http://192.168.88.163:30080`
2. **Login with defaults:**
   - Username: `admin`
   - Password: `adminadmin`
3. **Change password immediately!**
4. **Configure download paths:**
   - Default Save Path: `/downloads`
   - Keep default category settings
5. **Configure connection settings:**
   - Port: `6881` (already configured)
   - Enable UPnP if needed

### 2. Configure Sonarr

1. **Access Sonarr:** `http://192.168.88.163:30989`
2. **Complete setup wizard**
3. **Add Download Client:**
   - Settings → Download Clients → Add qBittorrent
   - Host: `qbittorrent.qbittorrent.svc.cluster.local`
   - Port: `8080`
   - Username: `admin`
   - Password: (your new password)
   - Category: `tv-sonarr` (optional)

4. **Configure Root Folders:**
   - Settings → Media Management → Root Folders
   - Add: `/tv` (this maps to your Jellyfin TV shows folder)

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

## Resource Configuration

**Sonarr:**
- Memory: 256Mi request, 1Gi limit
- CPU: 100m request, 500m limit

**qBittorrent:**
- Memory: 256Mi request, 1Gi limit  
- CPU: 100m request, 500m limit

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
   - Monitor available space on NFS share
   - Configure automatic removal of completed downloads
   - Use quality profiles appropriate for Pi playback

3. **Indexer Configuration:**
   - Use reliable indexers with good API limits
   - Configure reasonable search intervals
   - Monitor failed downloads and adjust settings

## Troubleshooting

### Check pod status:
```bash
kubectl get pods -n sonarr
kubectl get pods -n qbittorrent
kubectl describe pod <pod-name> -n <namespace>
kubectl logs -f deployment/sonarr -n sonarr
kubectl logs -f deployment/qbittorrent -n qbittorrent
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
ls -la /mnt/storage/sonarr/downloads/
ls -la /mnt/storage/jellyfin/media/tv-shows/
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

1. Use ReadWriteMany storage for all volumes
2. Configure external databases
3. Implement proper session management
4. Consider active/passive failover

## Upgrading

To upgrade applications:
```bash
kubectl set image deployment/sonarr sonarr=linuxserver/sonarr:latest -n sonarr
kubectl set image deployment/qbittorrent qbittorrent=linuxserver/qbittorrent:latest -n qbittorrent
kubectl rollout status deployment/sonarr -n sonarr
kubectl rollout status deployment/qbittorrent -n qbittorrent
```

## Cleanup

To remove everything:
```bash
kubectl delete namespace sonarr
kubectl delete namespace qbittorrent
# Manually remove NFS directories if desired
ssh pi@node03 "sudo rm -rf /mnt/storage/{sonarr,qbittorrent}"
```

## Useful Links

- [Sonarr Documentation](https://wiki.servarr.com/sonarr)
- [qBittorrent Documentation](https://github.com/qbittorrent/qBittorrent/wiki)
- [LinuxServer.io Docker Images](https://docs.linuxserver.io/)