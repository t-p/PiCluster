# Pi-hole DNS Ad Blocker

Pi-hole provides network-wide DNS ad blocking and filtering for the entire cluster. It acts as a DNS server that blocks ads, trackers, and malicious domains at the DNS level.

## Architecture

Pi-hole runs as a single container deployment with:
- **Primary upstream**: Internal Unbound recursive resolver (`unbound.dns.svc.cluster.local:5053`)
- **Fallback upstream**: Router DNS (`192.168.88.1`)
- **DNSSEC**: Validated by Unbound during recursive resolution
- **Caching**: Pi-hole and Unbound both cache responses

Normal queries use Unbound. The router is a secondary availability fallback.

## Features

- Network-wide ad blocking at DNS level
- Custom blocklists with automatic updates
- DNS filtering for malicious domains
- Web interface for management and statistics
- High availability via LoadBalancer service
- Comprehensive logging and monitoring

## Configuration

### DNS Servers
Pi-hole uses strict primary/secondary ordering:
1. **Unbound**: `unbound.dns.svc.cluster.local:5053`, full recursive IPv4 resolver with DNSSEC validation
2. **Router**: `192.168.88.1`, used when Unbound is unavailable

### Storage
- **Config**: `/mnt/storage/pihole/` (NFS persistent storage)
- **Logs**: Managed with automatic rotation and cleanup
- **Database**: Pi-hole FTL database for query logging

## Deployment

The Pi-hole deployment consists of:

### ConfigMaps
- `unbound-config`: Unbound recursive resolver configuration
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

Unbound handles full recursive resolution and DNSSEC validation by contacting authoritative DNS servers directly. The router at `192.168.88.1` is used only as Pi-hole's secondary fallback.

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
kubectl apply -f apps/pihole/06-unbound.yaml
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
