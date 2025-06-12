# Transmission with VPN on PiCluster


This directory contains Kubernetes manifests to deploy Transmission BitTorrent client with integrated VPN protection using Gluetun on your PiCluster K3s setup.

## Overview

Transmission is a fast, easy, and free BitTorrent client. This deployment includes:

- **Transmission**: BitTorrent client with web interface
- **Gluetun**: VPN client providing secure tunnel (Mullvad configured)
- **Integrated storage**: Shared download directories for Sonarr/Radarr integration

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (192.168.88.163)
- Mullvad credentials (stored as Kubernetes secret)
- At least 1GB RAM available across worker nodes
- Privileged containers support for VPN functionality
- All resources deployed in the `downloads` namespace

## Security Features

1. **VPN Kill Switch**: All traffic blocked if VPN disconnects
2. **Firewall Protection**: Only permitted ports accessible
3. **Non-root Transmission**: Runs as user 1000
4. **Secure DNS**: DNS queries through VPN tunnel
5. **Network Isolation**: Traffic only through VPN interface

## Quick Start

1. **Create Mullvad credentials secret:**
   ```bash
   kubectl create secret generic mullvad-credentials \
     --from-literal=WIREGUARD_PRIVATE_KEY='<your-mullvad-private-key>' \
     --from-literal=WIREGUARD_ADDRESSES='<your-mullvad-address>' \
     --from-literal=DNS='<your-custom-dns-server>' \
     -n downloads
   ```

2. **Deploy Transmission with VPN:**
   ```bash
   cd apps/transmission
   kubectl apply -f 01-storage.yaml
   kubectl apply -f 02-deployment.yaml
   kubectl apply -f 03-service.yaml
   ```

3. **Access Transmission:**
   - Web interface: `http://192.168.88.162:9091/transmission/web/`
   - Or any node IP: `http://192.168.88.16X:9091/transmission/web/`
   - Or via NodePort: `http://<node-ip>:<nodeport>` (see `kubectl get svc -n downloads`)

## Troubleshooting

### Check pod status:
```bash
kubectl get pods -n downloads
kubectl describe pod <pod-name> -n downloads
kubectl logs -f deployment/transmission-vpn -n downloads -c gluetun
kubectl logs -f deployment/transmission-vpn -n downloads -c transmission
```

### Common issues:

**Pod stuck in Pending:**
- Check if NFS directories exist with correct permissions
- Verify privileged container support is enabled
- Check node resources and scheduling constraints

**VPN connection issues:**
- Verify Mullvad credentials in secret
- Check Gluetun logs for connection details
- Test VPN health endpoint connectivity

## Manual Deployment

If you prefer step-by-step deployment:

```bash
# Create NFS directory for config only (downloads are now shared via shared PVC)
ssh pi@192.168.88.163 "sudo mkdir -p /mnt/storage/transmission/config"
ssh pi@192.168.88.163 "sudo chown -R 1000:1000 /mnt/storage/transmission"

# Create VPN credentials secret (replace with your credentials)
kubectl create secret generic mullvad-credentials \
  --from-literal=WIREGUARD_PRIVATE_KEY='your-private-key' \
  --from-literal=WIREGUARD_ADDRESSES='your-address' \
  --from-literal=DNS='your-custom-dns-server' \
  -n downloads

# Deploy main application
kubectl apply -f 01-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Storage Structure

Transmission now uses a shared NFS directory for downloads, shared with Sonarr and Radarr via the `shared-downloads-pvc` in the `downloads` namespace. This PVC is mounted at `/downloads` in the Transmission pod.

```
/mnt/storage/
├── shared/
│   └── downloads/                 # Shared downloads directory (managed by provisioner)
│       ├── complete/
│       │   ├── radarr/            # Radarr movie downloads (category)
│       │   └── tv-sonarr/         # Sonarr TV downloads (category)
│       └── incomplete/
├── transmission/
│   └── config/                    # Transmission configuration and torrents
```

**Note:**  
You do not need to manually create `/mnt/storage/shared/downloads/`. The NFS Subdir External Provisioner and the shared PVC (`shared-downloads-pvc`) handle all subdirectory creation and management for downloads.

### Accessing Downloads

To check the shared downloads directory:
```bash
kubectl exec -n downloads deployment/transmission-vpn -c transmission -- ls -l /downloads/complete/
```
Or on the NFS server, look under `/mnt/storage/shared/downloads/complete/`.

**You do not need to create or manage static PVCs or PVs for downloads. All apps (Sonarr, Radarr, Transmission) now use the same shared PVC (`shared-downloads-pvc`) in the `downloads` namespace, mounted at `/downloads`.**

## VPN Configuration

### Mullvad Settings

The deployment is configured for Mullvad with:
- **Protocol**: WireGuard (fast and secure)
- **Server**: Amsterdam (configurable via SERVER_CITIES env var)
- **Firewall**: Enabled with kill-switch functionality
- **DNS**: Custom DNS server configured in secret

### DNS Configuration

The deployment uses a custom DNS server instead of the default VPN provider DNS:
- **DNS Server**: Configurable custom DNS server IP
- **Storage**: Configured in the `mullvad-credentials` secret
- **Purpose**: Provides custom DNS resolution for all VPN traffic
- **Security**: DNS queries are still routed through the VPN tunnel

To update the DNS server:
```bash
kubectl patch secret mullvad-credentials -n downloads -p '{"data":{"DNS":"<base64-encoded-dns-ip>"}}'
```

### Firewall Protection

Gluetun provides firewall protection that:
- Blocks all traffic when VPN is down
- Only allows traffic through VPN interface
- Permits specific ports: 9091 (web UI), 51413 (torrents)
- Provides health check endpoint on port 9999

## Resource Configuration

**Gluetun (VPN):**
- Privileged container (required for VPN)
- Runs as root (VPN requirement)
- Health checks on port 9999

**Transmission:**
- Memory: 256Mi request, 1Gi limit
- CPU: 100m request, 500m limit
- Runs as user 1000 for security
- Flood UI interface enabled

## Integration with Sonarr/Radarr

Transmission, Sonarr, and Radarr all use the same dynamically provisioned NFS PVC (`shared-downloads-pvc`) for downloads. Categories in Transmission (e.g., `radarr`, `tv-sonarr`) ensure that completed downloads are placed in separate subdirectories under `/downloads/complete/`, which are visible to all apps.

Configure in Sonarr/Radarr:
1. Set download client category/label appropriately (e.g., `radarr` for movies, `tv-sonarr` for TV)
2. Transmission will automatically create subdirectories for each category under `/downloads/complete/`
3. Sonarr and Radarr will import files from their respective subdirectories

**All apps must reference `/downloads` as the download directory in their configuration, as this is the shared mount point for the shared PVC.**

## Performance Tips

1. **VPN Optimization:**
   - Choose nearby VPN servers for better speed
   - Use TCP protocol for stability in containers
   - Monitor VPN connection health regularly

2. **Download Management:**
   - Limit concurrent downloads (3-5 max for Pi hardware)
   - Use reasonable upload/download speed limits
   - Enable bandwidth scheduling for off-peak hours

3. **Storage Optimization:**
   - Monitor NFS share capacity
   - Configure automatic cleanup of old torrents
   - Use appropriate disk cache settings

### VPN Health Check:
```bash
# Port forward health check
kubectl port-forward deployment/transmission-vpn 9999:9999 -n transmission &
curl http://localhost:9999

# Check public IP (should show VPN IP)
kubectl exec -it deployment/transmission-vpn -n transmission -c transmission -- curl -s ifconfig.me
```

### Access storage directly:
```bash
# On master node
ssh pi@192.168.88.163
ls -la /mnt/storage/shared/downloads/complete/
```

**Transmission not accessible:**
- Ensure VPN is connected and healthy
- Check firewall settings in Gluetun
- Verify service and port configuration

**Download issues:**
- Check available storage space
- Verify torrent ports (51413) are accessible
- Monitor peer connections and tracker responses

## Configuration Customization

### Changing VPN Server:
```yaml
# In 02-deployment.yaml, modify:
- name: SERVER_CITIES
  value: "Stockholm"  # Or any Mullvad city
```

## ARM64 Optimizations

- Uses official Docker images with ARM64 support
- Conservative resource limits for Pi hardware
- Optimized for low-power operation
- Runs on worker nodes only to preserve master resources

## Upgrading

To upgrade components:
```bash
# Update Gluetun
kubectl patch deployment transmission-vpn -n downloads -p '{"spec":{"template":{"spec":{"containers":[{"name":"gluetun","image":"qmcgaw/gluetun:latest"}]}}}}'

# Update Transmission
kubectl patch deployment transmission-vpn -n downloads -p '{"spec":{"template":{"spec":{"containers":[{"name":"transmission","image":"linuxserver/transmission:latest"}]}}}}'

# Check rollout status
kubectl rollout status deployment/transmission-vpn -n downloads
```

## Cleanup

To remove Transmission and VPN:
```bash
kubectl delete deployment transmission-vpn -n downloads
kubectl delete svc transmission-vpn -n downloads
# Manually remove NFS config directory if desired
ssh pi@192.168.88.163 "sudo rm -rf /mnt/storage/transmission"
```

## Security Considerations

1. **VPN Credentials**: Store securely as Kubernetes secrets
2. **Network Policies**: Consider implementing network policies for additional isolation
3. **Resource Limits**: Prevent resource exhaustion
4. **Regular Updates**: Keep VPN client and Transmission updated
5. **Audit Logs**: Monitor download activity and VPN connections

## Scaling Considerations

This deployment uses a single replica for several reasons:
1. VPN connections are typically single-instance
2. BitTorrent client state management
3. Storage consistency requirements

For high availability, consider:
1. Active/passive failover setup
2. External state management
3. Load balancing at the service level

## Useful Links

- [Transmission Documentation](https://github.com/transmission/transmission/wiki)
- [Gluetun VPN Client](https://github.com/qdm12/gluetun)
- [Mullvad Setup Guide](https://mullvad.net/en/help/wireguard-and-mullvad-vpn)
- [LinuxServer.io Docker Images](https://docs.linuxserver.io/images/docker-transmission)
- [Flood UI Documentation](https://flood.js.org/)
