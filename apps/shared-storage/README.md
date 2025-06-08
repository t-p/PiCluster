# Shared Storage Configuration

This directory contains the Kubernetes configuration for shared storage resources used across multiple applications in the PiCluster.

## Overview

The shared downloads storage allows both Sonarr and Transmission to access the same download directory, eliminating path mapping issues and ensuring seamless file sharing between services.

## Files

- `shared-downloads-storage.yaml` - Complete configuration (PV + both PVCs)
- `shared-downloads-pv.yaml` - Shared PersistentVolume only
- `sonarr-shared-downloads-pvc.yaml` - Sonarr's PersistentVolumeClaim
- `transmission-shared-downloads-pvc.yaml` - Transmission's PersistentVolumeClaim
- `deploy-shared-downloads.sh` - Automated deployment script
- `README.md` - This file

## Storage Architecture

### Before (Separate Downloads)
```
Transmission: /mnt/storage/transmission/downloads/ → /downloads/
Sonarr:       /mnt/storage/sonarr/downloads/      → /downloads/
```
**Problem**: Services can't see each other's files

### After (Shared Downloads)
```
Both Services: /mnt/storage/shared/downloads/ → /downloads/
```
**Solution**: Both services access the same physical directory

## Directory Structure

```
/mnt/storage/shared/downloads/
├── complete/     # Transmission completed downloads
├── incomplete/   # Transmission in-progress downloads
└── [other dirs]  # Additional download categories
```

## Deployment

### Prerequisites
1. Create shared directory on NFS server:
   ```bash
   ssh pi@192.168.88.163 "sudo mkdir -p /mnt/storage/shared/downloads/{complete,incomplete}"
   ssh pi@192.168.88.163 "sudo chown -R 1000:1000 /mnt/storage/shared/downloads/"
   ```

2. Copy existing downloads to shared location (optional)

### Automated Deployment
```bash
cd PiCluster/apps/shared-storage
./deploy-shared-downloads.sh
```

### Manual Deployment
```bash
# Scale down services
kubectl scale deployment sonarr --replicas=0 -n sonarr
kubectl scale deployment transmission-vpn --replicas=0 -n transmission

# Remove old storage
kubectl delete pvc sonarr-downloads-pvc -n sonarr
kubectl delete pvc transmission-downloads-pvc -n transmission
kubectl delete pv sonarr-downloads-pv transmission-downloads-pv

# Deploy shared storage
kubectl apply -f shared-downloads-storage.yaml

# Scale services back up
kubectl scale deployment sonarr --replicas=1 -n sonarr
kubectl scale deployment transmission-vpn --replicas=1 -n transmission
```

## Verification

After deployment, verify both services can access the shared storage:

```bash
# Check mount points
kubectl exec -n sonarr deployment/sonarr -- df -h | grep downloads
kubectl exec -n transmission deployment/transmission-vpn -c transmission -- df -h | grep downloads

# Check directory contents
kubectl exec -n sonarr deployment/sonarr -- ls -la /downloads/
kubectl exec -n transmission deployment/transmission-vpn -c transmission -- ls -la /downloads/
```

## Configuration Details

### PersistentVolume
- **Name**: `shared-downloads-pv`
- **Capacity**: 200Gi
- **Access Mode**: ReadWriteMany
- **NFS Path**: `/mnt/storage/shared/downloads`
- **Server**: 192.168.88.163

### PersistentVolumeClaims
Both Sonarr and Transmission PVCs bind to the same PV using label selectors:
- **Selector**: `type: shared-downloads`
- **Access Mode**: ReadWriteMany
- **Storage Request**: 200Gi

## Benefits

- ✅ **Eliminates path mapping errors** between Sonarr and Transmission
- ✅ **Instant file visibility** - both services see downloads immediately
- ✅ **Simplified configuration** - no remote path mapping needed
- ✅ **Better reliability** - single source of truth for downloads
- ✅ **Easier troubleshooting** - one location to check for files

## Troubleshooting

### PVC Won't Bind
```bash
kubectl describe pvc sonarr-downloads-pvc -n sonarr
kubectl describe pvc transmission-downloads-pvc -n transmission
```
Check that the PV exists and has the correct label selector.

### Mount Issues
```bash
kubectl describe pv shared-downloads-pv
```
Verify NFS server accessibility and path existence.

### Services Can't Start
```bash
kubectl logs -n sonarr deployment/sonarr
kubectl logs -n transmission deployment/transmission-vpn -c transmission
```
Check for mount-related errors in pod logs.

## Rollback

If you need to rollback to separate downloads:

1. Scale down services
2. Delete shared PVCs and PV
3. Recreate original separate PVs and PVCs
4. Scale services back up

Keep backups of your original configurations before deploying shared storage.