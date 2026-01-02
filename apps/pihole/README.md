# Pi-hole DNS Ad Blocker

Pi-hole provides network-wide DNS ad blocking and filtering for the entire cluster. It acts as a DNS server that blocks ads, trackers, and malicious domains at the DNS level.

## Architecture

Pi-hole runs as a single container deployment with:
- **Primary DNS**: Router (192.168.88.1) with NextDNS DoH integration
- **Fallback DNS**: Cloudflare (1.1.1.1)
- **DNSSEC**: Disabled (handled by router)
- **Caching**: Pi-hole provides DNS caching for improved performance

## Features

- Network-wide ad blocking at DNS level
- Custom blocklists with automatic updates
- DNS filtering for malicious domains
- Web interface for management and statistics
- High availability via LoadBalancer service
- Comprehensive logging and monitoring

## Configuration

### DNS Servers
Pi-hole is configured to use:
1. **Router (192.168.88.1)**: Primary DNS with NextDNS DoH integration
2. **Cloudflare (1.1.1.1)**: Fallback DNS server

### Storage
- **Config**: `/mnt/storage/pihole/` (NFS persistent storage)
- **Logs**: Managed with automatic rotation and cleanup
- **Database**: Pi-hole FTL database for query logging

## Deployment

The Pi-hole deployment consists of:

### ConfigMaps
- `pihole-config`: Main Pi-hole configuration
- `pihole-custom-dnsmasq`: Custom dnsmasq settings for Kubernetes
- `pihole-logging-config`: Log rotation and cleanup scripts

### Services
- **LoadBalancer**: DNS service (port 53) available on all cluster nodes
- **NodePort**: Web interface on port 31080

### CronJobs
- **Gravity Update**: Daily blocklist updates
- **Log Cleanup**: Regular log maintenance

## Access

- **Web Interface**: `http://192.168.88.167:31080/admin/`
- **DNS Service**: Available on all cluster node IPs (port 53)

## Network Integration

Pi-hole is configured as the primary DNS server for:
- All cluster nodes (`/etc/resolv.conf`)
- DHCP clients (via router configuration)
- Kubernetes pods (via cluster DNS)

The router (192.168.88.1) handles:
- NextDNS DoH integration for privacy
- DNSSEC validation
- Upstream DNS resolution

This architecture provides optimal performance and privacy while maintaining simplicity.

## Deployment Steps

### Step 1: Create the Secret (Required)
```bash
kubectl create secret generic pihole-secret \
  --from-literal=WEBPASSWORD='your-secure-password-here' \
  --namespace=dns
```

### Step 2: Deploy Pi-hole
```bash
kubectl apply -f apps/pihole/01-namespace-and-storage.yaml
kubectl apply -f apps/pihole/04-configmaps.yaml
kubectl apply -f apps/pihole/03-services.yaml
kubectl apply -f apps/pihole/02-deployment.yaml
kubectl apply -f apps/pihole/05-cronjob.yaml
```

### Step 3: Verify Deployment
```bash
kubectl get pods -n dns
kubectl get services -n dns
```

## Testing

```bash
# Test DNS resolution
kubectl exec -n dns deployment/pihole -- dig @127.0.0.1 google.com +short

# Test ad blocking
kubectl exec -n dns deployment/pihole -- dig @127.0.0.1 doubleclick.net +short
```

## Maintenance

```bash
# Restart Pi-hole
kubectl rollout restart deployment/pihole -n dns

# Update blocklists manually
kubectl create job --from=cronjob/pihole-gravity-update manual-gravity-update -n dns

# Check logs
kubectl logs -n dns deployment/pihole
```
