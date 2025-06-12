# Shared Storage Configuration

This directory contains the Kubernetes configuration for shared storage resources used across multiple applications in the PiCluster.

## Overview

The shared downloads storage allows Sonarr, Radarr, and Transmission to access the same dynamically provisioned download directory, eliminating path mapping issues and ensuring seamless file sharing between services. This is managed by the NFS Subdir External Provisioner and a shared PVC (`shared-downloads-pvc`) in each namespace.

## Files

- `00-namespace-and-storage.yaml` - Namespace, PV, and PVC for shared downloads in the `downloads` namespace
- `README.md` - This file

## Storage Architecture

### Before (Separate Downloads)
```
Transmission: /mnt/storage/transmission/downloads/ → /downloads/
Sonarr:       /mnt/storage/sonarr/downloads/      → /downloads/
```
**Problem**: Services can't see each other's files

### After (Shared Downloads PVC)
```
All Services: /mnt/storage/shared/downloads/ → /downloads/
```
**Solution**: All services access the same dynamically provisioned NFS subdirectory via the shared PVC (`shared-downloads-pvc` in the `downloads` namespace)

## Directory Structure

```
/mnt/storage/shared/downloads/
├── complete/     # Completed downloads (with subfolders for categories, e.g., radarr, tv-sonarr)
│   ├── radarr/
│   └── tv-sonarr/
├── incomplete/   # In-progress downloads
└── [other dirs]  # Additional download categories
```

## Deployment

### Prerequisites
1. Ensure your NFS server exports the base path (e.g., `/mnt/storage`) and is accessible from your cluster nodes.

2. The NFS Subdir External Provisioner will automatically create a unique subdirectory for each PVC. You do not need to manually create subdirectories for downloads.

3. Copy existing downloads to the new dynamic subdirectory if migrating from a static setup (optional).

### Deployment

1. Deploy the NFS Subdir External Provisioner (see control-plane manifests).
2. In the `downloads` namespace, apply `00-namespace-and-storage.yaml` to create the shared PV and PVC:

```bash
kubectl apply -f 00-namespace-and-storage.yaml
```

3. Update each app's deployment (Sonarr, Radarr, Transmission) to mount the `shared-downloads-pvc` from the `downloads` namespace at `/downloads`.

4. Remove any old static PVCs and PVs for downloads if no longer needed. All new deployments should reference `00-namespace-and-storage.yaml` and the shared PVC.

## Verification

After deployment, verify all services can access the shared storage:

```bash
# Check mount points
kubectl exec -n downloads deployment/sonarr -- df -h | grep downloads
kubectl exec -n downloads deployment/radarr -- df -h | grep downloads
kubectl exec -n downloads deployment/transmission-vpn -c transmission -- df -h | grep downloads

# Check directory contents
kubectl exec -n downloads deployment/sonarr -- ls -la /downloads/
kubectl exec -n downloads deployment/radarr -- ls -la /downloads/
kubectl exec -n downloads deployment/transmission-vpn -c transmission -- ls -la /downloads/
```

## Configuration Details

### PersistentVolumeClaim (Shared PVC)
A single PVC named `shared-downloads-pvc` is created in the `downloads` namespace, using the `nfs` storage class. All apps (Sonarr, Radarr, Transmission) mount this shared PVC at `/downloads`. The NFS Subdir External Provisioner manages the subdirectory structure under `/mnt/storage/shared/downloads/`.

- **Access Mode**: ReadWriteMany
- **Storage Request**: 200Gi (or as needed)
- **StorageClass**: nfs (dynamic provisioner)
- **NFS Path**: `/mnt/storage/shared/downloads`

## Benefits

- ✅ **Eliminates path mapping errors** between Sonarr, Radarr, and Transmission
- ✅ **Instant file visibility** - all services see downloads immediately
- ✅ **Simplified configuration** - no remote path mapping needed
- ✅ **Better reliability** - single source of truth for downloads
- ✅ **Easier troubleshooting** - one location to check for files
- ✅ **Dynamic provisioning** - no need to manually create or manage NFS subdirectories

## Troubleshooting

### PVC Won't Bind
```bash
kubectl describe pvc shared-downloads-pvc -n sonarr
kubectl describe pvc shared-downloads-pvc -n radarr
kubectl describe pvc shared-downloads-pvc -n transmission
```
Check that the PVC uses the correct storage class (`nfs`) and that the NFS provisioner pod is running. The NFS path should be `/mnt/storage/downloads`.

### Mount Issues
```bash
kubectl describe pvc shared-downloads-pvc -n <namespace>
```
Verify NFS server accessibility and that the provisioner is creating the `downloads` subdirectory.

### Services Can't Start
```bash
kubectl logs -n sonarr deployment/sonarr
kubectl logs -n transmission deployment/transmission-vpn -c transmission
```
Check for mount-related errors in pod logs.

## Rollback

If you need to rollback to separate downloads:

1. Scale down services
2. Delete the shared PVCs in each namespace
3. Remove the dynamically provisioned `downloads` subdirectory from your NFS server if desired
4. Recreate original separate PVs and PVCs if needed
5. Scale services back up

Keep backups of your original configurations and data before deploying or rolling back shared storage.