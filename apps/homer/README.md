# Homer Dashboard on PiCluster

This directory contains Kubernetes manifests to deploy Homer, a beautiful static homepage for your PiCluster services.

## Overview

Homer is a simple static homepage that provides quick access to all your PiCluster services. It's lightweight, fast, and perfect for organizing your media server applications in a clean, responsive interface.

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (node03)
- Existing services deployed (Jellyfin, Sonarr, Radarr, qBittorrent, Jackett)
- At least 256MB RAM available

## Quick Start

1. **Deploy Homer Dashboard:**
   ```bash
   cd apps/homer
   ./deploy.sh
   ```

2. **Access Homer:**
   - Web interface: `http://192.168.88.163:30800`
   - LoadBalancer: `http://192.168.88.163:8080`

3. **Enjoy your organized dashboard!**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories
ssh pi@node03 "sudo mkdir -p /mnt/storage/homer/config"
ssh pi@node03 "sudo chown -R 1000:1000 /mnt/storage/homer"

# Copy configuration
scp homer-config.yml pi@node03:/tmp/config.yml
ssh pi@node03 "sudo mv /tmp/config.yml /mnt/storage/homer/config/"
ssh pi@node03 "sudo chown 1000:1000 /mnt/storage/homer/config/config.yml"

# Deploy manifests
kubectl apply -f 01-namespace-and-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Configuration

### Default Services Included

The dashboard includes direct links to:

**Media Services:**
- **Jellyfin** - Media streaming server
- **Sonarr** - TV show automation
- **Radarr** - Movie automation

**Download & Indexing:**
- **qBittorrent** - Torrent download client
- **Jackett** - Indexer proxy for trackers

**Cluster Management:**
- **Kubernetes Dashboard** - Cluster overview
- **Node Links** - Direct access to each Pi node

### Customizing the Dashboard

To customize your Homer dashboard:

1. **Edit the configuration:**
   ```bash
   ssh pi@node03 "sudo nano /mnt/storage/homer/config/config.yml"
   ```

2. **Add new services:**
   ```yaml
   - name: "New Service"
     logo: "assets/tools/service.png"
     subtitle: "Service Description"
     tag: "category"
     url: "http://192.168.88.163:PORT"
     target: "_blank"
   ```

3. **Restart Homer:**
   ```bash
   kubectl delete pod -n homer -l app=homer
   ```

### Adding Custom Icons

1. **Upload icons to assets directory:**
   ```bash
   ssh pi@node03 "sudo mkdir -p /mnt/storage/homer/config/tools"
   scp my-icon.png pi@node03:/tmp/
   ssh pi@node03 "sudo mv /tmp/my-icon.png /mnt/storage/homer/config/tools/"
   ```

2. **Reference in configuration:**
   ```yaml
   logo: "assets/tools/my-icon.png"
   ```

### Theme Customization

Homer supports light and dark themes. Edit the `colors` section in `config.yml`:

```yaml
colors:
  light:
    highlight-primary: "#your-color"
    background: "#your-background"
  dark:
    highlight-primary: "#your-color"
    background: "#your-background"
```

## Storage Structure

```
/mnt/storage/homer/
└── config/
    ├── config.yml      # Main configuration file
    └── tools/          # Custom icons and assets
        ├── service1.png
        └── service2.png
```

## Resource Configuration

- **Memory:** 64Mi request, 256Mi limit
- **CPU:** 50m request, 200m limit
- **Storage:** 1Gi for configuration and assets
- **Very lightweight** - perfect for Pi hardware

## Features

- **Responsive Design** - Works on desktop and mobile
- **Light/Dark Themes** - Automatic theme switching
- **Fast Loading** - Static files, no database
- **Search Functionality** - Quick service lookup
- **Keyboard Shortcuts** - Navigate with keyboard
- **Status Checking** - Optional service health monitoring

## Troubleshooting

### Check Homer Status:
```bash
kubectl get pods -n homer
kubectl logs -f deployment/homer -n homer
kubectl describe pod -n homer -l app=homer
```

### Common Issues:

**Homer not accessible:**
- Verify pod is running: `kubectl get pods -n homer`
- Check service: `kubectl get svc -n homer`
- Test with port forwarding: `kubectl port-forward -n homer svc/homer 8080:8080`

**Configuration not updating:**
- Restart the pod: `kubectl delete pod -n homer -l app=homer`
- Check file permissions: `ssh pi@node03 "ls -la /mnt/storage/homer/config/"`
- Verify YAML syntax in config file

**Services not linking correctly:**
- Check service URLs in configuration
- Verify all target services are running
- Test individual service access

### Access Configuration Directly:
```bash
# View current configuration
ssh pi@node03 "cat /mnt/storage/homer/config/config.yml"

# Edit configuration
ssh pi@node03 "sudo nano /mnt/storage/homer/config/config.yml"

# Check file permissions
ssh pi@node03 "ls -la /mnt/storage/homer/config/"
```

## Advanced Configuration

### Custom Links Section

Add external links in the configuration:

```yaml
links:
  - name: "GitHub"
    icon: "fab fa-github"
    url: "https://github.com"
    target: "_blank"
  - name: "Documentation"
    icon: "fas fa-book"
    url: "https://your-docs.com"
    target: "_blank"
```

### Service Groups

Organize services into logical groups:

```yaml
services:
  - name: "Media Services"
    icon: "fas fa-play"
    items:
      # Your media services here
      
  - name: "Development Tools"
    icon: "fas fa-code"
    items:
      # Your dev tools here
```

### Health Checking

Enable service status monitoring:

```yaml
- name: "Service Name"
  url: "http://service-url"
  endpoint: "/api/health"  # Health check endpoint
  # Homer will show green/red status indicators
```

## Performance Optimization

- **Static Assets:** Homer serves static files only
- **Caching:** Enable browser caching for better performance
- **CDN Icons:** Use CDN for common service icons
- **Minimize Config:** Keep configuration file small

## Security Considerations

- **No Authentication:** Homer is a static dashboard (add reverse proxy auth if needed)
- **Internal Network:** Best deployed on internal network only
- **HTTPS:** Consider adding TLS termination via ingress
- **Access Control:** Use Kubernetes NetworkPolicies if needed

## Backup and Recovery

### Backup Configuration:
```bash
# Backup Homer config
ssh pi@node03 "sudo cp /mnt/storage/homer/config/config.yml /tmp/homer-backup.yml"
scp pi@node03:/tmp/homer-backup.yml ./homer-backup-$(date +%Y%m%d).yml
```

### Restore Configuration:
```bash
# Restore from backup
scp homer-backup.yml pi@node03:/tmp/
ssh pi@node03 "sudo cp /tmp/homer-backup.yml /mnt/storage/homer/config/config.yml"
kubectl delete pod -n homer -l app=homer
```

## Upgrading

To upgrade Homer:
```bash
kubectl set image deployment/homer homer=b4bz/homer:latest -n homer
kubectl rollout status deployment/homer -n homer
```

## Integration Examples

### Adding Monitoring Services:
```yaml
- name: "Grafana"
  logo: "assets/tools/grafana.png"
  subtitle: "Metrics Dashboard"
  url: "http://192.168.88.163:3000"
  
- name: "Prometheus"
  logo: "assets/tools/prometheus.png"
  subtitle: "Metrics Collection"
  url: "http://192.168.88.163:9090"
```

### Adding Network Services:
```yaml
- name: "Pi-hole"
  logo: "assets/tools/pihole.png"
  subtitle: "DNS Ad Blocker"
  url: "http://192.168.88.163/admin"
  
- name: "UniFi Controller"
  logo: "assets/tools/unifi.png"
  subtitle: "Network Management"
  url: "https://192.168.88.163:8443"
```

## Cleanup

To remove Homer:
```bash
kubectl delete namespace homer
# Manually remove NFS directories if desired
ssh pi@node03 "sudo rm -rf /mnt/storage/homer"
```

## Useful Links

- [Homer GitHub](https://github.com/bastienwirtz/homer)
- [Homer Documentation](https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md)
- [Font Awesome Icons](https://fontawesome.com/icons)
- [Homer Themes](https://github.com/bastienwirtz/homer/tree/main/docs/themes)