# Homer Dashboard on PiCluster

This directory contains Kubernetes manifests to deploy Homer, a beautiful static homepage for your PiCluster services.

## Overview

Homer is a simple static homepage that provides quick access to all your PiCluster services. It's lightweight, fast, and perfect for organizing your media server applications in a clean, responsive interface.

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (192.168.88.163)
- Existing services deployed (Jellyfin, Sonarr, Radarr, Transmission, Jackett)
- At least 256MB RAM available

## Quick Start

1. Deploy Homer Dashboard:
   ```bash
   cd apps/homer
   kubectl apply -f 01-namespace-and-storage.yaml
   kubectl apply -f 02-deployment.yaml
   kubectl apply -f 03-service.yaml
   ```

2. Copy configuration to pod:
   ```bash
   kubectl cp homer-config.yml homer/$(kubectl get pod -n homer -l app=homer -o jsonpath='{.items[0].metadata.name}'):/www/assets/config.yml
   ```

3. Access Homer:
   - NodePort: http://192.168.88.162:30800

## Configuration

### Default Services Included

**Media Services:**
- Jellyfin - Media streaming server (http://192.168.88.162:8096)
- Sonarr - TV show automation (http://192.168.88.162:8989)
- Radarr - Movie automation (http://192.168.88.162:7878)

**Download & Indexing:**
- Transmission - BitTorrent client with VPN (http://192.168.88.162:9091)
- Jackett - Indexer proxy for trackers (http://192.168.88.162:9117)

**Cluster Management:**
- Kubernetes Dashboard - Cluster overview (https://192.168.88.162:30000)

## FontAwesome Icons

The configuration uses FontAwesome icons that work reliably:
- fas fa-home - Home/Dashboard
- fas fa-film - Movies (Jellyfin)
- fas fa-tv - TV Shows (Sonarr)
- fas fa-video - Movies (Radarr)
- fas fa-magnet - Torrents (Transmission)
- fas fa-search - Search/Indexing (Jackett)
- fas fa-cubes - Containers/Cluster (Kubernetes)

## Resource Configuration

- Memory: 64Mi request, 256Mi limit
- CPU: 50m request, 200m limit
- Storage: 100Mi for configuration
- Very lightweight - perfect for Pi hardware

## Troubleshooting

Check Homer Status:
```bash
kubectl get pods -n homer
kubectl logs -f deployment/homer -n homer
```

Update Configuration:
```bash
# Edit local config
nano homer-config.yml
# Copy to running pod
kubectl cp homer-config.yml homer/$(kubectl get pod -n homer -l app=homer -o jsonpath='{.items[0].metadata.name}'):/www/assets/config.yml
```

## Cleanup

To remove Homer:
```bash
kubectl delete namespace homer
ssh pi@192.168.88.163 "sudo rm -rf /mnt/storage/homer"
```

## Useful Links

- [Homer GitHub](https://github.com/bastienwirtz/homer)
- [Font Awesome Icons](https://fontawesome.com/icons)
