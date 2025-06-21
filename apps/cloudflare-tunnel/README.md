# Cloudflare Tunnel for Pi Cluster

This directory contains the Kubernetes manifests and scripts to set up a Cloudflare Tunnel for your Pi cluster, allowing secure access to your applications without port forwarding.

## Overview

Cloudflare Tunnel creates a secure connection between your Pi cluster and Cloudflare's edge network, providing:
- ✅ No port forwarding required
- ✅ Automatic SSL certificates
- ✅ DDoS protection
- ✅ Zero-trust security
- ✅ Geographic load balancing

## Prerequisites

1. **Cloudflare Account** (free tier works)
2. **Domain managed by Cloudflare**
3. **kubectl access** to your Pi cluster

## Current Status

✅ **Cloudflare Tunnel is already configured and running!**
✅ **Tunnel credentials secret is already created**
✅ **Deployment is active with 2 replicas**

## Verify Current Setup

```bash
# Check current deployment status
kubectl get pods -n cloudflare-tunnel
kubectl get deployment -n cloudflare-tunnel
kubectl logs -n cloudflare-tunnel deployment/cloudflared

# Check tunnel connectivity
kubectl get secret tunnel-credentials -n cloudflare-tunnel
```

## Add New Services to Tunnel

To add new services (like ArgoCD), go to your Cloudflare Tunnel dashboard and add hostnames:

| Service | Hostname | Service URL |
|---------|----------|-------------|
| ArgoCD | `argocd.yourdomain.com` | `http://argocd-server.argocd.svc.cluster.local:80` |
| Homer | `homer.yourdomain.com` | `http://homer.homer.svc.cluster.local:8080` |
| Jellyfin | `jellyfin.yourdomain.com` | `http://jellyfin.jellyfin.svc.cluster.local:8096` |
| Grafana | `grafana.yourdomain.com` | `http://grafana.monitoring.svc.cluster.local:3000` |

## Current Access URLs

Your applications are accessible at:
- `https://yourdomain.com` (main dashboard)
- Add new subdomains as needed via Cloudflare dashboard

## Files Description

### 02-deployment.yaml
- Deploys 2 replicas of the cloudflared container
- Configures health checks and resource limits
- Runs with security best practices (non-root, read-only filesystem)

### 03-service.yaml
- Exposes the cloudflared service internally
- Configured for monitoring integration

## Management Commands

### Check Tunnel Status
```bash
kubectl get pods -n cloudflare-tunnel
kubectl get deployment -n cloudflare-tunnel cloudflared
```

### View Logs
```bash
kubectl logs -n cloudflare-tunnel deployment/cloudflared
kubectl logs -n cloudflare-tunnel deployment/cloudflared -f  # Follow logs
```

### Restart Tunnel
```bash
kubectl rollout restart deployment/cloudflared -n cloudflare-tunnel
```

### Scale Tunnel
```bash
kubectl scale deployment cloudflared --replicas=3 -n cloudflare-tunnel
```

### Delete Tunnel
```bash
kubectl delete -f 02-deployment.yaml
kubectl delete -f 03-service.yaml
# Note: Secret is manually managed and not deleted
```

## Security Considerations

### Application Security
1. **Enable authentication** in all applications:
   - Jellyfin: Create user accounts with strong passwords
   - Sonarr/Radarr: Enable authentication in Settings → General
   - Transmission: Enable authentication in preferences

2. **Secure Transmission** (if exposing):
   - Use authentication
   - Consider IP whitelisting
   - Monitor download activity

### Cloudflare Security
1. **Access Policies**: Create Zero Trust policies for sensitive applications
2. **Rate Limiting**: Configure rate limiting rules
3. **WAF Rules**: Set up Web Application Firewall rules
4. **Country Blocking**: Block access from unwanted countries

## Troubleshooting

### Tunnel Not Connecting
```bash
# Check pod status
kubectl describe pod -n cloudflare-tunnel -l app=cloudflared

# Check logs for errors
kubectl logs -n cloudflare-tunnel deployment/cloudflared

# Verify secret exists
kubectl get secret tunnel-credentials -n cloudflare-tunnel
```

### Application Not Accessible
1. **Verify service is running**:
   ```bash
   kubectl get pods -n homer  # Replace with your app namespace
   kubectl get svc -n homer
   ```

2. **Test internal connectivity**:
   ```bash
   kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
     wget -qO- http://homer.homer.svc.cluster.local:8080
   ```

3. **Check Cloudflare configuration**:
   - Verify hostname configuration in Cloudflare dashboard
   - Ensure DNS records are properly configured

### SSL Issues
- Cloudflare automatically provides SSL certificates
- Check SSL/TLS settings in Cloudflare dashboard
- Ensure "Full" or "Full (strict)" encryption mode is enabled

## Monitoring

The deployment includes metrics exposure on port 2000:
- Health check: `http://localhost:2000/ready`
- Metrics: `http://localhost:2000/metrics`

If you have Prometheus installed, the ServiceMonitor will automatically discover and scrape metrics.

## Advanced Configuration

### Custom Configuration File
For advanced setups, you can use a configuration file instead of the token:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflare-tunnel
data:
  config.yaml: |
    tunnel: YOUR_TUNNEL_ID
    credentials-file: /etc/cloudflared/creds/credentials.json
    ingress:
      - hostname: homer.yourdomain.com
        service: http://homer.homer.svc.cluster.local:8080
      - hostname: jellyfin.yourdomain.com
        service: http://jellyfin.jellyfin.svc.cluster.local:8096
      - service: http_status:404
```

### Resource Limits
Adjust resource limits based on your cluster capacity:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

## Support

For issues with:
- **Kubernetes deployment**: Check the logs and pod status
- **Cloudflare configuration**: Refer to [Cloudflare Tunnel documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- **Application connectivity**: Verify service endpoints and networking

## Cleanup

To remove the Cloudflare Tunnel deployment (keeps secret):

```bash
kubectl delete -f 03-service.yaml
kubectl delete -f 02-deployment.yaml
```

To completely remove including the namespace and secret:
```bash
kubectl delete namespace cloudflare-tunnel
```

Don't forget to also delete the tunnel from your Cloudflare dashboard if you're done with it.
