# Jellyfin on PiCluster

This directory contains Kubernetes manifests to deploy Jellyfin media server on your PiCluster K3s setup.

## Overview

Jellyfin is a free and open-source media server that allows you to organize, manage, and stream your media collection. This deployment is optimized for ARM64 Raspberry Pi Compute Module 4 nodes.

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (node03)
- At least 2GB RAM available across worker nodes
- Media files stored on NFS share

## Quick Start

1. **Deploy Jellyfin:**
   ```bash
   cd apps/jellyfin
   ./deploy.sh
   ```

2. **Access Jellyfin:**
   - Web interface: `http://192.168.88.163:30096`
   - Or any node IP: `http://192.168.88.16X:30096`

3. **Complete setup wizard and add media libraries**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories
ssh pi@node03 "sudo mkdir -p /mnt/storage/jellyfin/{media,config}"
ssh pi@node03 "sudo chown -R 1000:1000 /mnt/storage/jellyfin"

# Deploy manifests
kubectl apply -f 01-namespace-and-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Storage Structure

```
/mnt/storage/jellyfin/
├── config/          # Jellyfin configuration and database
└── media/           # Your media files
    ├── movies/
    ├── tv-shows/
    ├── music/
    └── photos/
```

## Resource Configuration

The deployment is configured with:
- **Memory:** 512Mi request, 2Gi limit
- **CPU:** 250m request, 1000m limit
- **Cache:** 5Gi temporary storage
- **Config:** 10Gi persistent storage
- **Media:** 500Gi persistent storage

## ARM64 Optimizations

- Uses official Jellyfin Docker image with ARM64 support
- Conservative resource limits for Pi hardware
- No hardware acceleration (limited on Pi CM4)
- Runs on worker nodes only to preserve master resources

## Performance Tips

1. **Transcode Settings:**
   - Disable hardware acceleration in Jellyfin settings
   - Use lower quality transcoding profiles
   - Pre-convert high bitrate content for better performance

2. **Storage Optimization:**
   - Use H.264 instead of H.265 for better Pi compatibility
   - Keep media files in efficient formats
   - Consider separate fast storage for transcoding cache

3. **Network:**
   - Ensure gigabit network for smooth streaming
   - Place frequently accessed content on local storage if possible

## Troubleshooting

### Check pod status:
```bash
kubectl get pods -n jellyfin
kubectl describe pod <pod-name> -n jellyfin
kubectl logs -f deployment/jellyfin -n jellyfin
```

### Common issues:

**Pod stuck in Pending:**
- Check if NFS directories exist and have correct permissions
- Verify NFS server is running on master node

**Out of Memory errors:**
- Reduce concurrent streams
- Lower transcoding quality
- Increase resource limits if cluster has capacity

**Slow performance:**
- Check network connectivity
- Verify media file formats are Pi-friendly
- Monitor CPU/memory usage with `kubectl top pods -n jellyfin`

### Access NFS storage:
```bash
# On master node
ls -la /mnt/storage/jellyfin/
# Upload media files to /mnt/storage/jellyfin/media/
```

## Scaling Considerations

This deployment uses a single replica for simplicity. For high availability:

1. Use ReadWriteMany storage for all volumes
2. Increase replica count to 2-3
3. Configure pod anti-affinity rules
4. Consider external database for configuration

## Security Notes

- Jellyfin runs as user ID 1000 for security
- Media volume is mounted read-only
- No external ingress configured by default
- Consider adding TLS termination for external access

## Upgrading

To upgrade Jellyfin:
```bash
kubectl set image deployment/jellyfin jellyfin=jellyfin/jellyfin:latest -n jellyfin
kubectl rollout status deployment/jellyfin -n jellyfin
```

## Cleanup

To remove Jellyfin:
```bash
kubectl delete namespace jellyfin
# Manually remove NFS directories if desired
ssh pi@node03 "sudo rm -rf /mnt/storage/jellyfin"
```