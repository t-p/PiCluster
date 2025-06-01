# ProtonVPN on PiCluster

This directory contains setup files and scripts to deploy ProtonVPN using Gluetun on your PiCluster K3s setup.

## Overview

ProtonVPN integration provides secure VPN connectivity for your media stack services, ensuring all download traffic is encrypted and routed through ProtonVPN servers. This setup uses Gluetun, a lightweight VPN client container that supports ProtonVPN.

## Prerequisites

- PiCluster with K3s installed and running
- ProtonVPN account with OpenVPN credentials
- kubectl configured and working
- At least 128MB RAM available per VPN instance

## ProtonVPN Account Setup

Before deploying, you need to get your ProtonVPN OpenVPN credentials:

1. **Login to ProtonVPN Account:**
   - Go to https://account.protonvpn.com/
   - Navigate to "Account" → "OpenVPN/IKEv2 username"

2. **Get Your Credentials:**
   - **Username**: Your OpenVPN username (different from account username)
   - **Password**: Your OpenVPN password
   - **Server**: Choose a server (e.g., "nl-free-01" for free tier)

## Quick Start

1. **Configure your credentials:**
   ```bash
   cd apps/protonvpn
   cp credentials-template.env credentials.env
   nano credentials.env  # Add your ProtonVPN credentials
   ```

2. **Deploy ProtonVPN:**
   ```bash
   ./deploy.sh
   ```

3. **Verify VPN connection:**
   ```bash
   kubectl logs -f deployment/protonvpn -n vpn
   ```

4. **Test VPN connectivity:**
   ```bash
   kubectl exec -it deployment/protonvpn -n vpn -- curl ifconfig.me
   ```

## Manual Setup

If you prefer manual setup:

### 1. Create credentials file:
```bash
# Copy template and edit
cp credentials-template.env credentials.env
nano credentials.env
```

### 2. Deploy manifests:
```bash
kubectl apply -f 01-namespace.yaml
kubectl create secret generic protonvpn-credentials --from-env-file=credentials.env -n vpn
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-deployment.yaml
kubectl apply -f 04-service.yaml
```

## Files Included

- **01-namespace.yaml** - Creates VPN namespace
- **02-configmap.yaml** - VPN configuration settings
- **03-deployment.yaml** - Gluetun ProtonVPN deployment
- **04-service.yaml** - Service to expose VPN connectivity
- **credentials-template.env** - Template for VPN credentials
- **deploy.sh** - Automated deployment script
- **README.md** - This documentation

## Configuration Options

### Server Selection

Edit the ConfigMap to change ProtonVPN servers:

```yaml
# For free tier users
VPN_SERVICE_PROVIDER: "protonvpn"
FREE_ONLY: "on"
SERVER_COUNTRIES: "Netherlands,Japan"

# For paid users (more server options)
FREE_ONLY: "off"
SERVER_COUNTRIES: "Switzerland,Netherlands,United States"
```

### VPN Features

The setup includes:

- **Kill Switch**: Blocks traffic if VPN disconnects
- **DNS over HTTPS**: Secure DNS resolution
- **IPv6 Disabled**: Prevents IPv6 leaks
- **Firewall**: Blocks non-VPN traffic
- **Health Checks**: Automatic VPN monitoring

### Resource Limits

Default resource allocation:
- **Memory**: 64Mi request, 256Mi limit
- **CPU**: 50m request, 200m limit
- **Suitable for Pi hardware**

## Using VPN with Other Services

### Method 1: Sidecar Container (Recommended)

Add VPN as a sidecar to existing services:

```yaml
spec:
  containers:
  - name: your-app
    image: your-app:latest
    # App configuration
  - name: gluetun
    image: qmcgaw/gluetun
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
    env:
    - name: VPN_SERVICE_PROVIDER
      value: "protonvpn"
    # VPN configuration
```

### Method 2: Shared Network Namespace

Route specific pods through VPN:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: your-app
spec:
  containers:
  - name: your-app
    image: your-app:latest
  shareProcessNamespace: true
  # Network configuration to use VPN
```

### Method 3: Network Policies

Use Kubernetes NetworkPolicies to route traffic through VPN service.

## Integrating with qBittorrent

To route qBittorrent through ProtonVPN:

### Option A: Update qBittorrent Deployment

Modify your qBittorrent deployment to use VPN sidecar:

```yaml
# Add to qBittorrent pod spec
containers:
- name: gluetun
  image: qmcgaw/gluetun
  securityContext:
    capabilities:
      add: ["NET_ADMIN"]
  envFrom:
  - secretRef:
      name: protonvpn-credentials
  - configMapRef:
      name: protonvpn-config
```

### Option B: Separate VPN Gateway

Use the standalone VPN service as a gateway (more complex setup).

## Monitoring and Troubleshooting

### Check VPN Status:
```bash
# Check pod status
kubectl get pods -n vpn

# View logs
kubectl logs -f deployment/protonvpn -n vpn

# Check VPN IP
kubectl exec -it deployment/protonvpn -n vpn -- curl -s ifconfig.me

# Test DNS resolution
kubectl exec -it deployment/protonvpn -n vpn -- nslookup google.com
```

### Common Issues:

**VPN won't connect:**
- Verify ProtonVPN credentials in secret
- Check server availability: `kubectl logs deployment/protonvpn -n vpn`
- Ensure correct server name format

**DNS resolution fails:**
- Check DOH settings in ConfigMap
- Verify firewall rules aren't blocking DNS

**Pod stuck in pending:**
- Check node resources: `kubectl describe node`
- Verify PersistentVolume claims if using storage

**Kill switch not working:**
- Verify NET_ADMIN capability is granted
- Check iptables rules in pod: `kubectl exec -it deployment/protonvpn -n vpn -- iptables -L`

### VPN Health Monitoring:

```bash
# Check VPN connection health
kubectl exec -it deployment/protonvpn -n vpn -- \
  curl -s "https://ipinfo.io/json" | jq .

# Monitor VPN reconnections
kubectl logs deployment/protonvpn -n vpn | grep -i "connection\|disconnect\|reconnect"

# Check VPN server location
kubectl exec -it deployment/protonvpn -n vpn -- \
  curl -s "https://ipapi.co/json" | jq '.country, .city, .org'
```

## Security Considerations

### Credential Security:
- VPN credentials stored as Kubernetes secrets
- Secrets are base64 encoded (not encrypted at rest by default)
- Consider using sealed-secrets or external secret management

### Network Security:
- Kill switch prevents traffic leaks if VPN fails
- All traffic forced through VPN tunnel
- DNS queries encrypted via DNS over HTTPS
- IPv6 disabled to prevent leaks

### Best Practices:
- **Regular credential rotation** for ProtonVPN account
- **Monitor VPN logs** for connection issues
- **Test kill switch** functionality periodically
- **Use dedicated VPN account** for cluster

## ProtonVPN Server Selection

### Free Tier Servers:
- **Netherlands**: `nl-free-01.protonvpn.net`
- **Japan**: `jp-free-01.protonvpn.net` 
- **United States**: `us-free-01.protonvpn.net`

### Paid Tier Benefits:
- Access to all server locations
- Higher connection speeds
- More server options
- Better for high-bandwidth applications

### Server Configuration:

```yaml
# In ConfigMap, specify servers
SERVER_COUNTRIES: "Netherlands"
# Or specific servers
VPN_ENDPOINT_IP: "nl-free-01.protonvpn.net"
```

## Performance Optimization

### For Pi Hardware:
- Use lightweight server locations (geographically close)
- Limit concurrent connections
- Monitor CPU and memory usage
- Consider dedicated VPN node if needed

### Network Performance:
```bash
# Test VPN speed
kubectl exec -it deployment/protonvpn -n vpn -- \
  curl -o /dev/null -s -w "Speed: %{speed_download} bytes/sec\n" \
  http://speedtest.protonvpn.com/

# Check latency
kubectl exec -it deployment/protonvpn -n vpn -- \
  ping -c 4 8.8.8.8
```

## Advanced Configuration

### Custom DNS Servers:
```yaml
# In ConfigMap
DOT: "off"
DNS_ADDRESS: "1.1.1.1,8.8.8.8"
```

### Port Forwarding (Paid plans):
```yaml
# Enable port forwarding for better torrent connectivity
VPN_PORT_FORWARDING: "on"
VPN_PORT_FORWARDING_PROVIDER: "protonvpn"
```

### Multiple VPN Instances:
Deploy multiple VPN instances for different services or geographic locations.

## Backup and Recovery

### Backup Configuration:
```bash
# Export VPN configuration
kubectl get configmap protonvpn-config -n vpn -o yaml > protonvpn-config-backup.yaml
kubectl get secret protonvpn-credentials -n vpn -o yaml > protonvpn-credentials-backup.yaml
```

### Disaster Recovery:
1. Restore namespace and RBAC
2. Recreate secrets from backup
3. Apply configuration and deployment manifests
4. Verify VPN connectivity

## Integration with Homer Dashboard

Add ProtonVPN status to your Homer dashboard:

```yaml
- name: "ProtonVPN"
  icon: "fas fa-shield-alt"
  subtitle: "VPN Gateway"
  tag: "security"
  url: "http://192.168.88.163:30090"  # If exposing VPN status page
  target: "_blank"
```

## Upgrading

To upgrade Gluetun:
```bash
kubectl set image deployment/protonvpn gluetun=qmcgaw/gluetun:latest -n vpn
kubectl rollout status deployment/protonvpn -n vpn
```

## Cleanup

To remove ProtonVPN:
```bash
kubectl delete namespace vpn
# Remove any modified application deployments that used VPN
```

## Alternative VPN Providers

Gluetun also supports:
- ExpressVPN
- NordVPN
- Surfshark
- Private Internet Access
- Many others

## Useful Links

- [Gluetun Documentation](https://github.com/qdm12/gluetun)
- [ProtonVPN OpenVPN Configuration](https://protonvpn.com/support/openvpn-linux-setup/)
- [Kubernetes Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [ProtonVPN Server List](https://protonvpn.com/vpn-servers)