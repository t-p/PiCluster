# Pi-hole DNS Ad Blocker with Unbound

Network-wide DNS ad blocking and recursive DNS resolution service for the Kubernetes cluster.

## Overview

- **Namespace**: `dns`
- **Images**: `pihole/pihole:2024.07.0` + `klutchell/unbound:1.24.2` (sidecar)
- **Access**: Web UI NodePort 31080, DNS LoadBalancer port 53
- **Storage**: 1Gi NFS persistent volume
- **Database**: Pi-hole FTL database (SQLite)
- **Upstream DNS**: Unbound recursive resolver (sidecar on localhost:5335)

## Architecture

Pi-hole runs with an Unbound sidecar container providing recursive DNS resolution:

```
Client → Pi-hole (port 53) → Unbound (localhost:5335) → Root DNS servers
```

**Benefits:**
- **Privacy**: No queries sent to third-party DNS providers
- **Performance**: Local caching and recursive resolution
- **Security**: DNSSEC validation enabled
- **Ad Blocking**: Pi-hole blocks ads/trackers before resolution

## Components

### 01-namespace-and-storage.yaml
- Creates `dns` namespace
- Creates `pihole-config-pvc` PVC (1Gi NFS storage)
- **Note**: `pihole-secret` must be created manually (see Deployment section)

### 02-deployment.yaml
- Pi-hole deployment with Unbound sidecar container
- **Pi-hole container**: DNS ad blocking and web interface
- **Unbound sidecar**: Recursive DNS resolver on localhost:5335
- Runs on node01 with appropriate security contexts
- Resource limits: Pi-hole (500m CPU, 512Mi memory), Unbound (200m CPU, 256Mi memory)
- Health probes for DNS (TCP/53) and web interface

### 03-services.yaml
- **DNS Service**: LoadBalancer on port 53 (TCP/UDP) with NodePort 31021
- **Web Service**: NodePort 31080 for admin interface access
- External traffic policy: Cluster

### 04-configmaps.yaml
- **pihole-config**: Environment variables and Pi-hole settings
- **pihole-custom-dnsmasq**: Kubernetes-specific DNS configuration and NTP whitelist
- **pihole-logging-config**: Log rotation and cleanup scripts
- **unbound-sidecar-config**: Unbound recursive DNS resolver configuration

### 05-cronjob.yaml
- **Gravity Update**: Daily blocklist updates at 2 AM (Amsterdam time)
- **Log Cleanup**: Daily log maintenance at 3 AM (Amsterdam time)

## Configuration

### Key Environment Variables
- `TZ`: Europe/Amsterdam
- `DNS1`: 127.0.0.1#5335 (Unbound sidecar)
- `DNS2`: 127.0.0.1#5335 (Unbound sidecar)
- `NTP_SERVERS`: pool.ntp.org (whitelisted NTP servers)
- `DNSMASQ_LISTENING`: all (accept queries from all interfaces)
- `WEBTHEME`: default-dark
- `QUERY_LOGGING`: true
- `DNSSEC`: true

### Unbound Configuration
- **Cache**: 75MB total (50MB rrset + 25MB message cache)
- **TTL**: 30 minutes minimum, 4 hours maximum
- **Prefetching**: Enabled for performance
- **DNSSEC**: Full validation enabled
- **Access Control**: Only localhost (Pi-hole) allowed
- **Privacy**: Hides server identity and version

### Port Configuration
- **DNS TCP/UDP**: 53 (internal and external)
- **Web Interface**: 80 (internal) → 31080 (NodePort)
- **DHCP**: 67 (disabled by default)

### Storage Mounts
- `/etc/pihole` → PVC subPath: pihole (configuration)
- `/etc/dnsmasq.d` → PVC subPath: dnsmasq.d (DNS config)
- `/var/log/pihole` → PVC subPath: logs (log files)

## Access URLs

### Web Interface
You can access Pi-hole admin through any cluster node:
- http://192.168.88.167:31080/admin/ (node01)
- http://192.168.88.164:31080/admin/ (node02)
- http://192.168.88.163:31080/admin/ (node03)
- http://192.168.88.162:31080/admin/ (node04)
- http://192.168.88.126:31080/admin/ (node05)

### DNS Service
Pi-hole DNS is available via LoadBalancer on all nodes:
- **Internal**: pihole-dns.dns.svc.cluster.local:53
- **External**: All node IPs on port 53 (TCP/UDP)

## Deployment

### Step 1: Create the Secret (Required)
**⚠️ SECURITY: Never commit secrets to Git!**

```bash
# Create the pihole-secret with web admin password
kubectl create secret generic pihole-secret \
  --from-literal=WEBPASSWORD='your-secure-password-here' \
  --namespace=dns
```

### Step 2: Deploy Pi-hole
```bash
# Apply all configurations in order
kubectl apply -f apps/pihole/01-namespace-and-storage.yaml
kubectl apply -f apps/pihole/04-configmaps.yaml
kubectl apply -f apps/pihole/03-services.yaml
kubectl apply -f apps/pihole/02-deployment.yaml
kubectl apply -f apps/pihole/05-cronjob.yaml
```

### Step 3: Verify Deployment
```bash
# Check pod status
kubectl get pods -n dns

# Check services
kubectl get services -n dns

# Check persistent volume
kubectl get pvc -n dns

# Check cronjobs
kubectl get cronjobs -n dns
```

## Features

- **Network-wide Ad Blocking**: Blocks ads and tracking at DNS level
- **Custom Blocklists**: Multiple curated blocklist sources with automatic updates
- **DNS Filtering**: Filters malicious and unwanted domains
- **Web Interface**: Easy-to-use admin dashboard for management
- **Query Logging**: Detailed DNS query logs and statistics
- **DNSSEC**: DNS Security Extensions enabled
- **High Availability**: LoadBalancer service across all cluster nodes
- **Automated Maintenance**: Daily blocklist updates and log cleanup
- **Kubernetes Integration**: Custom dnsmasq config for cluster compatibility

## Monitoring

### Health Checks
- **Liveness Probe**: TCP port 53 (DNS service)
- **Readiness Probe**: TCP port 53 (DNS service)  
- **Startup Probe**: HTTP /admin/ (Web interface)

### Log Locations
- **Pi-hole Logs**: `/var/log/pihole/pihole.log`
- **FTL Logs**: `/var/log/pihole/FTL.log`
- **DNS Query Logs**: Available in web interface
- **Container Logs**: `kubectl logs -n dns deployment/pihole`

### Statistics Access
- **Web Interface**: Statistics dashboard with real-time metrics
- **Query Log**: Detailed DNS query history
- **Blocklist Status**: Current blocklist counts and sources
- **Top Clients**: Most active DNS clients
- **Top Domains**: Most queried domains

## Maintenance

### Automated Tasks
- **Blocklist Updates**: Daily at 2:00 AM Amsterdam time via CronJob
- **Log Cleanup**: Daily at 3:00 AM Amsterdam time via CronJob
- **Log Rotation**: Automatic when logs exceed 100MB

### Manual Operations
```bash
# Restart Pi-hole
kubectl rollout restart deployment/pihole -n dns

# Update blocklists manually
kubectl create job --from=cronjob/pihole-gravity-update manual-gravity-update -n dns

# Clean logs manually  
kubectl create job --from=cronjob/pihole-log-cleanup manual-log-cleanup -n dns

# Check CronJob status
kubectl get cronjobs -n dns
kubectl get jobs -n dns
```

### Backup Configuration
```bash
# Backup Pi-hole configuration
kubectl exec -n dns deployment/pihole -- tar -czf /tmp/pihole-backup.tar.gz /etc/pihole
kubectl cp dns/$(kubectl get pods -n dns -l app=pihole -o jsonpath='{.items[0].metadata.name}'):/tmp/pihole-backup.tar.gz ./pihole-backup.tar.gz
```

## Troubleshooting

### Common Issues

#### DNS Resolution Not Working
```bash
# Check Pi-hole pod status
kubectl get pods -n dns -l app=pihole

# Check DNS service endpoints
kubectl get endpoints pihole-dns -n dns

# Test DNS resolution from cluster
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup google.com
```

#### Web Interface Not Accessible
```bash
# Check web service
kubectl get service pihole-web -n dns

# Check pod logs
kubectl logs -n dns deployment/pihole

# Test service connectivity
kubectl port-forward -n dns service/pihole-web 8080:80
```

#### High Resource Usage
```bash
# Check resource usage
kubectl top pods -n dns

# Check log sizes
kubectl exec -n dns deployment/pihole -- du -sh /var/log/pihole/

# Manual log cleanup
kubectl create job --from=cronjob/pihole-log-cleanup emergency-cleanup -n dns
```

#### Blocklist Update Failures
```bash
# Check gravity update job logs
kubectl logs -n dns job/pihole-gravity-update-<timestamp>

# Manual gravity update
kubectl exec -n dns deployment/pihole -- pihole -g

# Check disk space
kubectl exec -n dns deployment/pihole -- df -h
```

## Testing

### DNS Functionality
```bash
# Test basic DNS resolution
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup google.com

# Test ad blocking (should fail or return blocked response)
kubectl run adblock-test --image=busybox --rm -it --restart=Never -- nslookup doubleclick.net

# Test from external client
nslookup google.com 192.168.88.167
```

### Service Health
```bash
# Check all Pi-hole resources
kubectl get all -n dns

# Test web interface
curl -I http://192.168.88.167:31080/admin/

# Check LoadBalancer status
kubectl get service pihole-dns -n dns -o wide
```

## Security

### Access Control
- Web interface password protected via Kubernetes secret
- Network policies can be applied for additional security
- Runs in dedicated `dns` namespace with privileged security context

### Data Privacy
- Query logging can be disabled if needed
- Logs automatically rotated and cleaned up
- No data sent to external services (except upstream DNS)
- DNSSEC enabled for DNS security

## Performance

### Resource Usage
- **CPU**: ~50-100m under normal load
- **Memory**: ~150-300Mi depending on query volume  
- **Storage**: ~50MB for configuration, logs grow over time
- **Network**: Minimal bandwidth usage

### Scaling Considerations
- Single instance sufficient for home lab use
- Database shared via persistent volume
- Can be scaled horizontally if needed for high-traffic environments
- LoadBalancer provides high availability across nodes

## Integration

### Kubernetes DNS Integration
- CoreDNS forwards external queries to Pi-hole
- Internal cluster DNS (.cluster.local) handled by CoreDNS
- Custom dnsmasq configuration allows cluster pod queries
- Seamless integration with existing cluster services

### Monitoring Integration
- Prometheus metrics available (if Pi-hole exporter deployed)
- Grafana dashboards for DNS query visualization
- Log aggregation with cluster logging stack
- AlertManager integration for DNS service alerts

### Network Integration
- LoadBalancer service provides high availability
- Compatible with existing network policies
- MetalLB integration for external IP assignment
- Works with cluster ingress controllers

---

**Pi-hole provides comprehensive network-wide ad blocking and DNS filtering for your Kubernetes cluster with full automation and monitoring capabilities.**